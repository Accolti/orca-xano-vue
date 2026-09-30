-- =============================================================
-- Desconto somado (desconto% + desconto Pix%) na política de limite
-- e faixas_comissao devolve a equipe (para o override do Master).
-- =============================================================

create or replace function public.orcamento_recalcular(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id bigint := coalesce((p_payload->>'user_id')::bigint, 0);
  v_orca_id bigint := coalesce((p_payload->>'orca_id')::bigint, 0);
  v_new_margem numeric := nullif(p_payload->>'newMargem', '')::numeric;
  v_frt_b2c numeric := coalesce((p_payload->>'frtB2C')::numeric, 0);
  v_desconto numeric := coalesce((p_payload->>'desconto')::numeric, 0);
  v_mao_obra numeric := coalesce((p_payload->>'maoDeObra')::numeric, 0);
  v_observacao text := p_payload->>'observacao';
  v_cond_pgto text := p_payload->>'condicoesPagamento';
  v_cond_params text := p_payload->>'condicoesPagamentoParams';

  v_orca orca%rowtype;
  v_caller record;
  v_root record;
  v_root_id bigint;
  v_pai_id bigint;
  v_eh_filho boolean;
  v_livre numeric := 0;
  v_max_desc numeric := 0;
  v_aprovado boolean := true;
  v_status_desc text := 'aprovado';
  v_acima_max boolean := false;
  v_gross numeric := 0;
  v_desc_val numeric := 0;
  v_perc numeric := 0;
  v_pix_perc numeric := 0;
  v_pix_val numeric := 0;
  v_total_desc numeric := 0;
  v_margem_usar numeric;
  v_recalc jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select * into v_orca from orca where id = v_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if v_orca.user_id <> v_user_id then
    raise exception 'Acesso negado: apenas o dono pode alterar o orçamento.' using errcode = 'P0001';
  end if;
  if v_orca.eh_pedido is true then
    raise exception 'Orçamento convertido em pedido. Edição bloqueada.' using errcode = 'P0001';
  end if;

  select id, role, vendedor_pai_id, desconto_livre_perc, desconto_max_perc
    into v_caller from usuarios where id = v_user_id;

  v_root_id := f_empresa_id(v_user_id);
  select id, desconto_livre_perc, desconto_max_perc, frt_b2b
    into v_root from usuarios where id = v_root_id;

  v_eh_filho := (v_caller.role = 'vendedor' or v_caller.role = 'vendedor_master');

  v_margem_usar := v_new_margem;
  if v_eh_filho then
    v_margem_usar := null;
  end if;

  v_livre := coalesce(nullif(v_caller.desconto_livre_perc, 0), nullif(v_root.desconto_livre_perc, 0), 0);
  v_max_desc := coalesce(nullif(v_caller.desconto_max_perc, 0), nullif(v_root.desconto_max_perc, 0), 0);

  if v_eh_filho then
    v_gross := coalesce(v_orca.venda_bruta_tot, 0);
    if v_gross = 0 then
      v_gross := coalesce(v_orca.vnd_tot, 0) + coalesce(v_orca.desconto, 0);
    end if;
    if v_gross > 0 then
      v_desc_val := v_desconto;
      v_perc := v_desc_val * 100 / v_gross;

      v_pix_perc := 0;
      if v_cond_params is not null and v_cond_params <> '' then
        begin
          v_pix_perc := coalesce((v_cond_params::jsonb->>'descontoPixPercentual')::numeric, 0);
        exception when others then
          v_pix_perc := 0;
        end;
      end if;

      -- SOMA dos descontos: Pix aplicado sobre o líquido (vnd_tot = gross - desconto).
      v_pix_val := greatest(v_gross - v_desc_val, 0) * v_pix_perc / 100;
      v_total_desc := v_desc_val + v_pix_val;
      v_perc := v_total_desc * 100 / v_gross;

      if v_perc > v_max_desc then
        v_acima_max := true;
      end if;
      if v_perc > v_livre and v_total_desc > 0 then
        v_aprovado := false;
      end if;
    end if;
  end if;

  if not v_aprovado then
    v_status_desc := 'pendente';
  end if;

  if v_eh_filho and not v_aprovado and v_orca.desconto_status is distinct from 'pendente' then
    v_pai_id := coalesce(v_caller.vendedor_pai_id, 0);
    if v_pai_id > 0 then
      insert into notificacao (user_id, tipo, orca_id, lida) values (v_pai_id, 'desconto_pendente', v_orca_id, false);
    end if;
    if v_root_id > 0 and v_root_id <> v_pai_id then
      insert into notificacao (user_id, tipo, orca_id, lida) values (v_root_id, 'desconto_pendente', v_orca_id, false);
    end if;
  end if;

  if v_acima_max then
    raise exception 'Desconto acima do máximo permitido para a equipe.' using errcode = 'P0001';
  end if;

  update orca set
    frt_b2c = v_frt_b2c,
    desconto = v_desconto,
    desconto_aprovado = v_aprovado,
    desconto_status = v_status_desc,
    mao_de_obra = v_mao_obra,
    observacao = v_observacao,
    condicoes_pagamento = v_cond_pgto,
    condicoes_pagamento_params = v_cond_params
  where id = v_orca_id;

  v_recalc := orcamento_recalcular_totais(v_orca_id, v_margem_usar, coalesce(v_root.frt_b2b, 0));
  return v_recalc;
end;
$$;

-- Faixas de comissão + equipe (filhos diretos com percentual) para o override do Master.
create or replace function public.faixas_comissao(p_user_id bigint, p_target_user_id bigint default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_target_id bigint;
  v_faixas jsonb;
  v_equipe jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role, vendedor_pai_id, percentual_comissao into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  v_target_id := p_user_id;
  if v_me.role = 'vendedor' and coalesce(v_me.vendedor_pai_id, 0) > 0 then
    v_target_id := f_empresa_id(p_user_id);
  elsif v_me.role = 'vendedor_master' and coalesce(v_me.vendedor_pai_id, 0) > 0 then
    v_target_id := v_me.vendedor_pai_id;
  elsif v_me.role = 'admin_geral' and p_target_user_id is not null then
    v_target_id := p_target_user_id;
  end if;

  select coalesce(jsonb_agg(to_jsonb(f) order by f.faixa_min asc), '[]'::jsonb)
  into v_faixas
  from faixa_comissao f where f.user_id = v_target_id;

  select coalesce(jsonb_agg(
    jsonb_build_object('id', u.id, 'percentual_comissao', coalesce(u.percentual_comissao, 0))
    order by u.id
  ), '[]'::jsonb)
  into v_equipe
  from usuarios u where u.vendedor_pai_id = p_user_id;

  return jsonb_build_object(
    'faixas', v_faixas,
    'papel', v_me.role,
    'percentual_comissao', v_me.percentual_comissao,
    'empresa_id', v_target_id,
    'equipe', v_equipe
  );
end;
$$;
