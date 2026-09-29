-- =============================================================
-- Fase 5 — Notificações (sino) + Taxas (tela /taxas)
-- =============================================================

-- ---------- Notificações ----------

create or replace function public.notificacoes(p_user_id bigint, p_limite int default 20)
returns jsonb language plpgsql as $$
declare
  v_notifs jsonb;
  v_nao_lidas int;
begin
  select coalesce(jsonb_agg(x order by x.created_at desc), '[]'::jsonb)
  into v_notifs
  from (
    select n.id, n.user_id, n.tipo, n.orca_id, n.lida, n.created_at, o.cod_orca
    from notificacao n
    left join orca o on o.id = n.orca_id
    where n.user_id = p_user_id
    order by n.created_at desc
    limit greatest(coalesce(p_limite, 20), 1)
  ) x;

  select count(*) into v_nao_lidas from notificacao where user_id = p_user_id and lida is not true;

  return jsonb_build_object('notificacoes', v_notifs, 'nao_lidas', v_nao_lidas);
end;
$$;

create or replace function public.notificacoes_marcar_lida(p_user_id bigint)
returns jsonb language plpgsql as $$
begin
  update notificacao set lida = true, data_leitura = now()
  where user_id = p_user_id and lida is not true;
  return jsonb_build_object('ok', true);
end;
$$;

-- ---------- Taxas ----------

-- Admin: role explícita OU legado (sem role e sem pai = dono da conta).
create or replace function public.f_eh_admin(p_user_id bigint)
returns boolean language sql stable as $$
  select exists (
    select 1 from usuarios u
    where u.id = p_user_id
      and (
        u.role in ('admin', 'admin_geral')
        or ((u.role is null or u.role = '') and (u.vendedor_pai_id is null or u.vendedor_pai_id = 0))
      )
  )
$$;

-- Lista taxas da empresa + globais + provedores para a tela "Minhas taxas".
create or replace function public.taxas_banco_gerenciar(p_user_id bigint, p_target_user_id bigint default null)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_target_id bigint;
  v_empresa_id bigint;
  v_taxas jsonb;
  v_globais jsonb;
  v_provedores jsonb;
begin
  select id, role into v_me from usuarios where id = p_user_id;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores gerenciam as taxas.' using errcode = 'P0001';
  end if;

  v_target_id := p_user_id;
  if v_me.role = 'admin_geral' and p_target_user_id is not null then
    v_target_id := p_target_user_id;
  end if;
  v_empresa_id := f_empresa_id(v_target_id);

  select coalesce(jsonb_agg(
    to_jsonb(t) || jsonb_build_object('provedor', p.nome)
    order by t.parcelas asc
  ), '[]'::jsonb)
  into v_taxas
  from taxa_banco t
  join provedor p on p.id = t.provedor_id
  where t.user_id = v_empresa_id;

  select coalesce(jsonb_agg(
    to_jsonb(t) || jsonb_build_object('provedor', p.nome)
    order by t.parcelas asc
  ), '[]'::jsonb)
  into v_globais
  from taxa_banco t
  join provedor p on p.id = t.provedor_id
  where t.ativo is true and (t.user_id is null or t.user_id = 0);

  select coalesce(jsonb_agg(to_jsonb(p) order by p.nome asc), '[]'::jsonb)
  into v_provedores
  from provedor p where p.ativo is true;

  return jsonb_build_object(
    'taxas', v_taxas,
    'taxas_globais', v_globais,
    'provedores', v_provedores,
    'empresa_id', v_empresa_id,
    'papel', v_me.role
  );
end;
$$;

-- Cria/edita uma taxa de cartão da empresa.
create or replace function public.taxa_banco_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_dono_id bigint;
  v_empresa_id bigint;
  v_existente record;
  v_id bigint;
  v_canal text := nullif(p_payload->>'canal', '');
begin
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores gerenciam as taxas.' using errcode = 'P0001';
  end if;

  if coalesce((p_payload->>'parcelas')::int, 0) <= 0 then
    raise exception 'Informe o número de parcelas.' using errcode = 'P0001';
  end if;
  if p_payload->>'cc_taxa' is null then
    raise exception 'Informe a taxa do cartão.' using errcode = 'P0001';
  end if;
  if v_canal is not null and v_canal not in ('cartao_link', 'cartao_celular', 'cartao_pos') then
    raise exception 'Canal inválido.' using errcode = 'P0001';
  end if;

  v_dono_id := p_user_id;
  if v_me.role = 'admin_geral' and (p_payload->>'user_id') is not null and (p_payload->>'user_id') <> '' then
    v_dono_id := (p_payload->>'user_id')::bigint;
  end if;
  v_empresa_id := f_empresa_id(v_dono_id);

  if p_payload->>'id' is not null then
    v_id := (p_payload->>'id')::bigint;
    select id, user_id into v_existente from taxa_banco where id = v_id;
    if not found then
      raise exception 'Taxa não encontrada.' using errcode = 'P0001';
    end if;
    if v_me.role <> 'admin_geral' and v_existente.user_id <> v_empresa_id then
      raise exception 'Você não pode editar esta taxa.' using errcode = 'P0001';
    end if;

    update taxa_banco set
      user_id = v_empresa_id,
      provedor_id = (p_payload->>'provedor_id')::bigint,
      parcelas = (p_payload->>'parcelas')::int,
      cc_taxa = (p_payload->>'cc_taxa')::numeric,
      canal = v_canal,
      ativo = coalesce((p_payload->>'ativo')::boolean, true),
      origem = 'manual',
      atualizado_em = now()
    where id = v_id;
  else
    insert into taxa_banco (user_id, provedor_id, parcelas, cc_taxa, canal, ativo, origem, atualizado_em, created_at)
    values (
      v_empresa_id,
      (p_payload->>'provedor_id')::bigint,
      (p_payload->>'parcelas')::int,
      (p_payload->>'cc_taxa')::numeric,
      v_canal,
      coalesce((p_payload->>'ativo')::boolean, true),
      'manual',
      now(),
      now()
    ) returning id into v_id;
  end if;

  return (
    select to_jsonb(t) || jsonb_build_object('provedor', p.nome)
    from taxa_banco t join provedor p on p.id = t.provedor_id where t.id = v_id
  );
end;
$$;

-- Exclui uma taxa de cartão.
create or replace function public.taxa_banco_excluir(p_user_id bigint, p_id bigint)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_existente record;
  v_empresa_id bigint;
begin
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores gerenciam as taxas.' using errcode = 'P0001';
  end if;

  select id, user_id into v_existente from taxa_banco where id = p_id;
  if not found then
    raise exception 'Taxa não encontrada.' using errcode = 'P0001';
  end if;

  v_empresa_id := f_empresa_id(p_user_id);
  if v_me.role <> 'admin_geral' and v_existente.user_id <> v_empresa_id then
    raise exception 'Você não pode excluir esta taxa.' using errcode = 'P0001';
  end if;

  delete from taxa_banco where id = p_id;
  return null::jsonb;
end;
$$;

-- Cria/edita um provedor (banco) de taxas.
create or replace function public.provedor_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql as $$
declare
  v_me record;
  v_id bigint;
  v_nome text := nullif(p_payload->>'nome', '');
begin
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  select id, role into v_me from usuarios where id = p_user_id;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores gerenciam provedores.' using errcode = 'P0001';
  end if;
  if v_nome is null or v_nome = '' then
    raise exception 'Informe o nome do provedor.' using errcode = 'P0001';
  end if;

  if p_payload->>'id' is not null then
    v_id := (p_payload->>'id')::bigint;
    update provedor set
      nome = v_nome,
      url_taxas = nullif(p_payload->>'url_taxas', ''),
      metodo = coalesce(nullif(p_payload->>'metodo', ''), 'manual'),
      canal_default = nullif(p_payload->>'canal_default', ''),
      ativo = coalesce((p_payload->>'ativo')::boolean, true)
    where id = v_id;
  else
    insert into provedor (nome, url_taxas, metodo, canal_default, ativo, created_at)
    values (
      v_nome,
      nullif(p_payload->>'url_taxas', ''),
      coalesce(nullif(p_payload->>'metodo', ''), 'manual'),
      nullif(p_payload->>'canal_default', ''),
      coalesce((p_payload->>'ativo')::boolean, true),
      now()
    ) returning id into v_id;
  end if;

  return (select to_jsonb(p) from provedor p where p.id = v_id);
end;
$$;
