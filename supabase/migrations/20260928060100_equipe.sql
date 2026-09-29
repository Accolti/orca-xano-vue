-- =============================================================
-- Fase 5 — Equipe + Comissões + Faixas (F3)
-- =============================================================

-- Descendentes (ids) de um usuário pela cadeia vendedor_pai_id (sem o próprio).
create or replace function public.f_descendentes(p_root_id bigint)
returns setof bigint language sql stable as $$
  with recursive cte as (
    select id from usuarios where vendedor_pai_id = p_root_id
    union
    select u.id from usuarios u join cte on u.vendedor_pai_id = cte.id
  )
  select id from cte
$$;

-- Serviço de comissões habilitado (plano "plus" da empresa efetiva).
create or replace function public.f_tem_comissoes(p_user_id bigint)
returns boolean language sql stable as $$
  select coalesce((perfil_efetivo(p_user_id)->>'plano') = 'plus', false)
$$;

-- Lista a equipe (com ativo_efetivo). admin → filhos; admin_geral → todos.
create or replace function public.equipe(p_user_id bigint)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_lista jsonb;
begin
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  if v_me.role = 'admin_geral' then
    select coalesce(jsonb_agg(
      to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
      || jsonb_build_object('ativo_efetivo', f_ativo_efetivo(u.id))
      order by u.created_at desc
    ), '[]'::jsonb)
    into v_lista
    from usuarios u where u.id <> p_user_id;
  else
    select coalesce(jsonb_agg(
      to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
      || jsonb_build_object('ativo_efetivo', f_ativo_efetivo(u.id))
      order by u.created_at desc
    ), '[]'::jsonb)
    into v_lista
    from usuarios u where u.vendedor_pai_id = p_user_id;
  end if;

  return v_lista;
end;
$$;

-- Vincula uma conta existente como vendedor/master do admin.
create or replace function public.equipe_vincular(
  p_user_id bigint,
  p_email text,
  p_percentual_comissao numeric default null,
  p_role text default null
)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_alvo record;
  v_novo_role text := 'vendedor';
begin
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role not in ('admin', 'admin_geral') then
    raise exception 'Apenas administradores podem vincular vendedores.' using errcode = 'P0001';
  end if;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  select id, email, role, vendedor_pai_id into v_alvo from usuarios where lower(email) = lower(p_email);
  if not found then
    raise exception 'Usuário com esse e-mail não encontrado.' using errcode = 'P0001';
  end if;
  if v_alvo.id = p_user_id then
    raise exception 'Você não pode se vincular a si mesmo.' using errcode = 'P0001';
  end if;
  if v_alvo.role = 'admin_geral' then
    raise exception 'Não é possível vincular o administrador geral.' using errcode = 'P0001';
  end if;
  if coalesce(v_alvo.vendedor_pai_id, 0) > 0 then
    raise exception 'Este usuário já pertence a outra equipe.' using errcode = 'P0001';
  end if;

  if p_role = 'vendedor_master' then
    if v_me.role not in ('admin', 'admin_geral') then
      raise exception 'Apenas administradores podem vincular um Vendedor Master.' using errcode = 'P0001';
    end if;
    v_novo_role := 'vendedor_master';
  end if;

  update usuarios set
    role = v_novo_role,
    vendedor_pai_id = p_user_id,
    percentual_comissao = p_percentual_comissao
  where id = v_alvo.id;

  return (select to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
          from usuarios u where u.id = v_alvo.id);
end;
$$;

-- Salva o cadastro de um vendedor (snapshot completo).
create or replace function public.equipe_salvar(
  p_user_id bigint,
  p_target_id bigint,
  p_percentual_comissao numeric,
  p_ativo boolean,
  p_desconto_livre_perc numeric,
  p_desconto_max_perc numeric
)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_alvo record;
begin
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  select id, vendedor_pai_id into v_alvo from usuarios where id = p_target_id;
  if not found then
    raise exception 'Vendedor não encontrado.' using errcode = 'P0001';
  end if;
  if v_me.role <> 'admin_geral' and v_alvo.vendedor_pai_id <> p_user_id then
    raise exception 'Você não pode editar este vendedor.' using errcode = 'P0001';
  end if;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  update usuarios set
    percentual_comissao = p_percentual_comissao,
    ativo = p_ativo,
    desconto_livre_perc = p_desconto_livre_perc,
    desconto_max_perc = p_desconto_max_perc
  where id = p_target_id;

  return (select to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
          from usuarios u where u.id = p_target_id);
end;
$$;

-- Define o papel de um usuário (somente admin_geral).
create or replace function public.equipe_role(p_user_id bigint, p_target_id bigint, p_role text)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_alvo record;
  v_novo_pai bigint;
begin
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' then
    raise exception 'Apenas o administrador geral altera papéis.' using errcode = 'P0001';
  end if;
  if p_target_id = p_user_id then
    raise exception 'Você não pode alterar o próprio papel.' using errcode = 'P0001';
  end if;
  if p_role not in ('admin', 'vendedor', 'vendedor_master') then
    raise exception 'Papel inválido.' using errcode = 'P0001';
  end if;

  select id, vendedor_pai_id into v_alvo from usuarios where id = p_target_id;
  if not found then
    raise exception 'Usuário não encontrado.' using errcode = 'P0001';
  end if;

  v_novo_pai := v_alvo.vendedor_pai_id;
  if p_role = 'admin' then
    v_novo_pai := null;
  end if;

  update usuarios set role = p_role, vendedor_pai_id = v_novo_pai where id = p_target_id;
  return (select to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
          from usuarios u where u.id = p_target_id);
end;
$$;

-- Define o plano de um usuário/empresa (somente admin_geral).
create or replace function public.user_plano(p_user_id bigint, p_target_id bigint, p_plano text)
returns jsonb language plpgsql as $$
declare
  v_me record;
begin
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' then
    raise exception 'Apenas o administrador geral define planos.' using errcode = 'P0001';
  end if;
  if p_target_id is null then
    raise exception 'Informe o usuário.' using errcode = 'P0001';
  end if;
  if p_plano not in ('basico', 'plus') then
    raise exception 'Plano inválido.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from usuarios where id = p_target_id) then
    raise exception 'Usuário não encontrado.' using errcode = 'P0001';
  end if;

  update usuarios set plano = p_plano where id = p_target_id;
  return jsonb_build_object('id', p_target_id, 'plano', p_plano);
end;
$$;

-- Comissões por período (escopo por árvore/empresa).
create or replace function public.comissoes(
  p_user_id bigint,
  p_mes_inicio text default null,
  p_periodo text default null
)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_ini timestamptz := '-infinity';
  v_fim timestamptz := 'infinity';
  v_n int := 0;
  v_base_ano int;
  v_base_mes int;
  v_raw_mes text;
  v_linhas jsonb;
  v_totais jsonb;
begin
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  v_n := case p_periodo when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 when 'anual' then 12 else 0 end;
  v_raw_mes := coalesce(nullif(trim(coalesce(p_mes_inicio, '')), ''), to_char(current_date, 'YYYY-MM'));
  v_base_ano := split_part(v_raw_mes, '-', 1)::int;
  v_base_mes := split_part(v_raw_mes, '-', 2)::int;
  if v_n > 0 then
    v_ini := make_timestamptz(v_base_ano, v_base_mes, 1, 0, 0, 0, 'UTC');
    v_fim := make_timestamptz(v_base_ano, v_base_mes + v_n, 1, 0, 0, 0, 'UTC');
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'user_id', c.user_id,
      'vendedor', coalesce(nullif(uv.name_first, ''), 'Vendedor ' || c.user_id),
      'cod_orca', coalesce(nullif(o.cod_orca, ''), '#' || c.orca_id),
      'orca_id', c.orca_id,
      'percentual', coalesce(c.percentual, 0),
      'base', coalesce(c.base_valor, c.lucro_real_base, 0),
      'tipo', case when c.tipo = 'override' then 'override' else 'vendedor' end,
      'valor', coalesce(c.valor, 0),
      'status', case when c.status = 'paga' then 'paga' else 'calculada' end,
      'data_pagamento', c.data_pagamento,
      'data', to_char(c.created_at, 'YYYY-MM-DD')
    )
    order by c.created_at desc
  ), '[]'::jsonb)
  into v_linhas
  from comissao c
  join orca o on o.id = c.orca_id
  left join usuarios uv on uv.id = c.user_id
  where c.created_at >= v_ini and c.created_at < v_fim
    and (
      v_me.role = 'admin_geral'
      or c.user_id = p_user_id
      or (v_me.role in ('admin', 'vendedor_master') and c.user_id in (select f_descendentes(p_user_id)))
    );

  select jsonb_build_object(
    'calculada', jsonb_build_object(
      'qtd', coalesce(sum(case when (e.value->>'status') = 'calculada' then 1 else 0 end), 0),
      'total', round(coalesce(sum(case when (e.value->>'status') = 'calculada' then (e.value->>'valor')::numeric else 0 end), 0), 2)
    ),
    'paga', jsonb_build_object(
      'qtd', coalesce(sum(case when (e.value->>'status') = 'paga' then 1 else 0 end), 0),
      'total', round(coalesce(sum(case when (e.value->>'status') = 'paga' then (e.value->>'valor')::numeric else 0 end), 0), 2)
    )
  )
  into v_totais
  from jsonb_array_elements(v_linhas) e;

  return jsonb_build_object('linhas', v_linhas, 'totais', v_totais);
end;
$$;

-- Marca uma comissão como paga (empresa admin ancestral ou admin_geral).
create or replace function public.comissao_pagar(p_user_id bigint, p_comissao_id bigint)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_comissao record;
  v_dono_id bigint;
  v_cur bigint;
  v_pode boolean;
  v_guard int := 0;
begin
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, user_id into v_comissao from comissao where id = p_comissao_id;
  if not found then
    raise exception 'Comissão não encontrada.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  v_dono_id := v_comissao.user_id;
  v_pode := (v_me.role = 'admin_geral');
  if not v_pode and v_me.role in ('admin', 'admin_geral') then
    select coalesce(vendedor_pai_id, 0) into v_cur from usuarios where id = v_dono_id;
    while v_cur > 0 and v_guard < 50 loop
      if v_cur = p_user_id then
        v_pode := true;
        exit;
      end if;
      select coalesce(vendedor_pai_id, 0) into v_cur from usuarios where id = v_cur;
      v_guard := v_guard + 1;
    end loop;
  end if;

  if not v_pode then
    raise exception 'Você não pode pagar esta comissão.' using errcode = 'P0001';
  end if;

  update comissao set status = 'paga', data_pagamento = current_date where id = p_comissao_id;
  return (select to_jsonb(c) from comissao c where c.id = p_comissao_id);
end;
$$;

-- Faixas de comissão (resolução da empresa dona).
create or replace function public.faixas_comissao(p_user_id bigint, p_target_user_id bigint default null)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_target_id bigint;
  v_faixas jsonb;
begin
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

  return jsonb_build_object(
    'faixas', v_faixas,
    'papel', v_me.role,
    'percentual_comissao', v_me.percentual_comissao,
    'empresa_id', v_target_id
  );
end;
$$;

-- Cria/edita uma faixa de comissão.
create or replace function public.faixa_comissao_salvar(
  p_user_id bigint,
  p_id bigint default null,
  p_target_user_id bigint default null,
  p_faixa_min numeric default null,
  p_faixa_max numeric default null,
  p_comissao_total_perc numeric default null,
  p_ordem int default null,
  p_ativo boolean default true
)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_dono_id bigint;
  v_existente record;
  v_id bigint;
begin
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role not in ('admin', 'admin_geral') then
    raise exception 'Apenas administradores configuram faixas de comissão.' using errcode = 'P0001';
  end if;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;
  if coalesce(p_comissao_total_perc, 0) <= 0 then
    raise exception 'Informe a comissão total.' using errcode = 'P0001';
  end if;

  v_dono_id := p_user_id;
  if v_me.role = 'admin_geral' and p_target_user_id is not null then
    v_dono_id := p_target_user_id;
  end if;

  if p_id is not null then
    select id, user_id into v_existente from faixa_comissao where id = p_id;
    if not found then
      raise exception 'Faixa não encontrada.' using errcode = 'P0001';
    end if;
    if v_me.role <> 'admin_geral' and v_existente.user_id <> p_user_id then
      raise exception 'Você não pode editar esta faixa.' using errcode = 'P0001';
    end if;

    update faixa_comissao set
      user_id = v_dono_id,
      faixa_min = coalesce(p_faixa_min, 0),
      faixa_max = p_faixa_max,
      comissao_total_perc = p_comissao_total_perc,
      ordem = p_ordem,
      ativo = p_ativo
    where id = p_id;
    v_id := p_id;
  else
    insert into faixa_comissao (created_at, user_id, faixa_min, faixa_max, comissao_total_perc, ordem, ativo)
    values (now(), v_dono_id, coalesce(p_faixa_min, 0), p_faixa_max, p_comissao_total_perc, p_ordem, p_ativo)
    returning id into v_id;
  end if;

  return (select to_jsonb(f) from faixa_comissao f where f.id = v_id);
end;
$$;
