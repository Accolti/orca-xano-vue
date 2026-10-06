-- =============================================================
-- Dev tools — Estrutura (Linha/Tipo/Nível/Borda) CRUD
-- =============================================================
--
-- Complementa as dev tools (catálogo) com o cadastro de Linha, Tipo,
-- Nível e Borda (filhos de Material; Nível também depende de Linha/Tipo).
--
-- Leituras: sem checagem de identidade (mesmo padrão das leituras dev).
-- Escritas: auth_user_id() + f_eh_admin + f_ativo_efetivo.
-- Ao salvar/excluir, auto-incrementa versao_materiais para invalidar o
-- cache de catálogo do app (orca_catalogo_materiais_cache).
-- =============================================================

-- ---------------------------------------------------------------------------
-- Leituras (listas)
-- ---------------------------------------------------------------------------

create or replace function public.rpc_linhas_dev()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', l.id,
    'nome', l.nome,
    'material_id', l.material_id,
    'material_nome', m.nome,
    'created_at', l.created_at
  ) order by l.id), '[]'::jsonb)
  from linha l
  left join material m on m.id = l.material_id;
$$;

create or replace function public.rpc_tipos_dev()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'nome', t.nome,
    'material_id', t.material_id,
    'material_nome', m.nome,
    'order', t."order",
    'created_at', t.created_at
  ) order by t.id), '[]'::jsonb)
  from tipo t
  left join material m on m.id = t.material_id;
$$;

create or replace function public.rpc_niveis_dev()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', n.id,
    'nome', n.nome,
    'descricao', n.descricao,
    'material_id', n.material_id,
    'linha_id', n.linha_id,
    'tipo_id', n.tipo_id,
    'material_nome', m.nome,
    'linha_nome', l.nome,
    'tipo_nome', t.nome,
    'created_at', n.created_at
  ) order by n.id), '[]'::jsonb)
  from nivel n
  left join material m on m.id = n.material_id
  left join linha l on l.id = n.linha_id
  left join tipo t on t.id = n.tipo_id;
$$;

create or replace function public.rpc_bordas_dev()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id,
    'nome', b.nome,
    'obs', b.obs,
    'material_id', b.material_id,
    'material_nome', m.nome,
    'valor', b.valor,
    'unidade', b.unidade,
    'ativo', coalesce(b.ativo, true),
    'created_at', b.created_at
  ) order by b.id), '[]'::jsonb)
  from borda b
  left join material m on m.id = b.material_id;
$$;

-- ---------------------------------------------------------------------------
-- Escritas (CRUD)
-- ---------------------------------------------------------------------------

create or replace function public.f_bump_versao_materiais()
returns void language sql security definer set search_path = public as $$
  update configuracoes set versao_materiais = coalesce(versao_materiais, 0) + 1;
$$;

create or replace function public.linha_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id bigint := nullif(p_payload->>'linha_id', '')::bigint;
  v_nome text := nullif(p_payload->>'nome', '');
  v_material_id bigint := nullif(p_payload->>'material_id', '')::bigint;
  v_salvo bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  if coalesce((p_payload->>'excluir')::boolean, false) and v_id is not null then
    if exists (select 1 from nivel where linha_id = v_id)
       or exists (select 1 from produto where linha_id = v_id) then
      raise exception 'Linha em uso (Nível ou Produto). Não é possível excluir.' using errcode = 'P0001';
    end if;
    delete from linha where id = v_id;
    perform f_bump_versao_materiais();
    return jsonb_build_object('linha_id', v_id);
  end if;

  if v_nome is null then
    raise exception 'Informe o nome da linha.' using errcode = 'P0001';
  end if;

  if v_id is not null then
    update linha set nome = v_nome, material_id = v_material_id where id = v_id
    returning id into v_salvo;
  else
    insert into linha (nome, material_id, created_at)
    values (v_nome, v_material_id, now())
    returning id into v_salvo;
  end if;

  perform f_bump_versao_materiais();
  return jsonb_build_object('linha_id', v_salvo);
end;
$$;

create or replace function public.tipo_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id bigint := nullif(p_payload->>'tipo_id', '')::bigint;
  v_nome text := nullif(p_payload->>'nome', '');
  v_material_id bigint := nullif(p_payload->>'material_id', '')::bigint;
  v_order bigint := nullif(p_payload->>'order', '')::bigint;
  v_salvo bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  if coalesce((p_payload->>'excluir')::boolean, false) and v_id is not null then
    if exists (select 1 from nivel where tipo_id = v_id)
       or exists (select 1 from produto where tipo_id = v_id) then
      raise exception 'Tipo em uso (Nível ou Produto). Não é possível excluir.' using errcode = 'P0001';
    end if;
    delete from tipo where id = v_id;
    perform f_bump_versao_materiais();
    return jsonb_build_object('tipo_id', v_id);
  end if;

  if v_nome is null then
    raise exception 'Informe o nome do tipo.' using errcode = 'P0001';
  end if;

  if v_id is not null then
    update tipo set nome = v_nome, material_id = v_material_id, "order" = coalesce(v_order, 0) where id = v_id
    returning id into v_salvo;
  else
    insert into tipo (nome, material_id, "order", created_at)
    values (v_nome, v_material_id, coalesce(v_order, 0), now())
    returning id into v_salvo;
  end if;

  perform f_bump_versao_materiais();
  return jsonb_build_object('tipo_id', v_salvo);
end;
$$;

create or replace function public.nivel_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id bigint := nullif(p_payload->>'nivel_id', '')::bigint;
  v_nome text := nullif(p_payload->>'nome', '');
  v_descricao text := nullif(p_payload->>'descricao', '');
  v_material_id bigint := nullif(p_payload->>'material_id', '')::bigint;
  v_linha_id bigint := nullif(p_payload->>'linha_id', '')::bigint;
  v_tipo_id bigint := nullif(p_payload->>'tipo_id', '')::bigint;
  v_salvo bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  if coalesce((p_payload->>'excluir')::boolean, false) and v_id is not null then
    if exists (select 1 from produto where nivel_id = v_id) then
      raise exception 'Nível em uso (Produto). Não é possível excluir.' using errcode = 'P0001';
    end if;
    delete from nivel where id = v_id;
    perform f_bump_versao_materiais();
    return jsonb_build_object('nivel_id', v_id);
  end if;

  if v_nome is null then
    raise exception 'Informe o nome do nível.' using errcode = 'P0001';
  end if;

  if v_id is not null then
    update nivel set
      nome = v_nome,
      descricao = v_descricao,
      material_id = v_material_id,
      linha_id = v_linha_id,
      tipo_id = v_tipo_id
    where id = v_id
    returning id into v_salvo;
  else
    insert into nivel (nome, descricao, material_id, linha_id, tipo_id, created_at)
    values (v_nome, v_descricao, v_material_id, v_linha_id, v_tipo_id, now())
    returning id into v_salvo;
  end if;

  perform f_bump_versao_materiais();
  return jsonb_build_object('nivel_id', v_salvo);
end;
$$;

create or replace function public.borda_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_id bigint := nullif(p_payload->>'borda_id', '')::bigint;
  v_nome text := nullif(p_payload->>'nome', '');
  v_obs text := nullif(p_payload->>'obs', '');
  v_material_id bigint := nullif(p_payload->>'material_id', '')::bigint;
  v_valor numeric := coalesce((p_payload->>'valor')::numeric, 0);
  v_unidade text := nullif(p_payload->>'unidade', '');
  v_ativo boolean := coalesce((p_payload->>'ativo')::boolean, true);
  v_salvo bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  if coalesce((p_payload->>'excluir')::boolean, false) and v_id is not null then
    if exists (select 1 from tipo_fator where borda_id = v_id) then
      raise exception 'Borda em uso (associação de fator de corte). Não é possível excluir.' using errcode = 'P0001';
    end if;
    delete from borda where id = v_id;
    perform f_bump_versao_materiais();
    return jsonb_build_object('borda_id', v_id);
  end if;

  if v_nome is null then
    raise exception 'Informe o nome da borda.' using errcode = 'P0001';
  end if;

  if v_id is not null then
    update borda set
      nome = v_nome,
      obs = v_obs,
      material_id = v_material_id,
      valor = v_valor,
      unidade = v_unidade,
      ativo = v_ativo
    where id = v_id
    returning id into v_salvo;
  else
    insert into borda (nome, obs, material_id, valor, unidade, ativo, created_at)
    values (v_nome, v_obs, v_material_id, v_valor, v_unidade, v_ativo, now())
    returning id into v_salvo;
  end if;

  perform f_bump_versao_materiais();
  return jsonb_build_object('borda_id', v_salvo);
end;
$$;
