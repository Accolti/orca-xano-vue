-- =============================================================
-- Fase 2B — orcamento_recalcular (política de desconto F3 + cabeçalho + recalc)
-- =============================================================

create or replace function public.orcamento_recalcular(p_payload jsonb)
returns jsonb language plpgsql as $$
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
  v_margem_usar numeric;
  v_recalc jsonb;
begin
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

  -- filho não altera margem (newMargem ignorado)
  v_margem_usar := v_new_margem;
  if v_eh_filho then
    v_margem_usar := null;
  end if;

  -- limites: próprio > 0 senão herda o padrão da empresa (raiz); sem nada = 0
  v_livre := coalesce(nullif(v_caller.desconto_livre_perc, 0), nullif(v_root.desconto_livre_perc, 0), 0);
  v_max_desc := coalesce(nullif(v_caller.desconto_max_perc, 0), nullif(v_root.desconto_max_perc, 0), 0);

  -- política de desconto (só para filho)
  if v_eh_filho then
    v_gross := coalesce(v_orca.venda_bruta_tot, 0);
    if v_gross = 0 then
      v_gross := coalesce(v_orca.vnd_tot, 0) + coalesce(v_orca.desconto, 0);
    end if;
    if v_gross > 0 then
      v_desc_val := v_desconto;
      v_perc := v_desc_val * 100 / v_gross;

      -- desconto Pix informado nas condições entra na mesma política
      v_pix_perc := 0;
      if v_cond_params is not null and v_cond_params <> '' then
        begin
          v_pix_perc := coalesce((v_cond_params::jsonb->>'descontoPixPercentual')::numeric, 0);
        exception when others then
          v_pix_perc := 0;
        end;
      end if;

      if v_pix_perc > v_perc then
        v_perc := v_pix_perc;
        v_desc_val := v_gross * v_perc / 100;
      end if;

      if v_perc > v_max_desc then
        v_acima_max := true;
      end if;
      if v_perc > v_livre and v_desc_val > 0 then
        v_aprovado := false;
      end if;
    end if;
  end if;

  if not v_aprovado then
    v_status_desc := 'pendente';
  end if;

  -- notificação aos ancestrais quando vira pendente (1ª vez)
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

  -- grava cabeçalho (frtB2C/desconto/mao_de_obra/observacao/condicoes sempre, inclusive 0)
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

  -- recalcula com a margem efetiva e o frete B2B da raiz
  v_recalc := orcamento_recalcular_totais(v_orca_id, v_margem_usar, coalesce(v_root.frt_b2b, 0));
  return v_recalc;
end;
$$;
