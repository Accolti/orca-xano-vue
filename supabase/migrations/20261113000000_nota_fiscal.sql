-- =============================================================
-- Notas Fiscais (XML NF-e) — upload + parsing no front + vínculo com pedido.
--
-- - Admin/empresa (admin, admin_geral ou legado sem role e sem pai) importa/gerencia.
-- - Vendedores visualizam apenas as NFs vinculadas a um pedido que podem ver
--   (nota_fiscal_por_orca, via f_pode_ver_orca).
-- - XML é gravado como text (arquivo pequeno); metadados + itens (jsonb) para exibição.
-- =============================================================

create table if not exists public.nota_fiscal (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  user_id bigint not null,
  orca_id bigint references public.orca(id) on delete set null,
  chave text not null unique,
  numero text,
  serie text,
  data_emissao date,
  tp_nf int,
  natureza_operacao text,
  emitente_cnpj text,
  emitente_nome text,
  emitente_ie text,
  destinatario_cnpj text,
  destinatario_nome text,
  valor_total numeric,
  valor_produtos numeric,
  valor_frete numeric,
  valor_ipi numeric,
  valor_icms numeric,
  itens jsonb not null default '[]'::jsonb,
  xml text not null
);

alter table public.nota_fiscal enable row level security;

create index if not exists nota_fiscal_orca_id_idx on public.nota_fiscal (orca_id);
create index if not exists nota_fiscal_user_id_idx on public.nota_fiscal (user_id);
create index if not exists nota_fiscal_chave_idx on public.nota_fiscal (chave);

-- Admin da empresa: role admin/admin_geral, ou legado sem role e sem pai.
create or replace function public.f_eh_admin_empresa(p_user_id bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from usuarios u
    where u.id = p_user_id
      and (
        u.role in ('admin', 'admin_geral')
        or ((u.role is null or u.role = '') and (u.vendedor_pai_id is null or u.vendedor_pai_id = 0))
      )
  );
$$;

-- Lista as NFs (admin da empresa vê as da própria empresa; admin_geral vê todas).
create or replace function public.nota_fiscal_listar(p_user_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_role text;
  v_empresa bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin_empresa(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;

  select role into v_role from usuarios where id = p_user_id;

  if v_role = 'admin_geral' then
    return coalesce((
      select jsonb_agg(to_jsonb(n) order by n.created_at desc, n.id desc)
      from nota_fiscal n
    ), '[]'::jsonb);
  end if;

  v_empresa := f_empresa_id(p_user_id);
  return coalesce((
    select jsonb_agg(to_jsonb(n) order by n.created_at desc, n.id desc)
    from nota_fiscal n
    where n.user_id = v_empresa
  ), '[]'::jsonb);
end;
$$;

-- Salva/vincula uma NF (upsert por chave). Só admin da empresa.
create or replace function public.nota_fiscal_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_chave text := nullif(trim(p_payload->>'chave'), '');
  v_xml text := coalesce(p_payload->>'xml', '');
  v_orca_id bigint := nullif(p_payload->>'orca_id', '')::bigint;
  v_id bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin_empresa(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;
  if v_chave is null or v_xml = '' then
    raise exception 'Informe a chave e o XML da nota.' using errcode = 'P0001';
  end if;

  insert into nota_fiscal (
    user_id, orca_id, chave, numero, serie, data_emissao, tp_nf, natureza_operacao,
    emitente_cnpj, emitente_nome, emitente_ie, destinatario_cnpj, destinatario_nome,
    valor_total, valor_produtos, valor_frete, valor_ipi, valor_icms, itens, xml
  ) values (
    p_user_id,
    v_orca_id,
    v_chave,
    nullif(trim(p_payload->>'numero'), ''),
    nullif(trim(p_payload->>'serie'), ''),
    nullif(p_payload->>'data_emissao', '')::date,
    nullif(p_payload->>'tp_nf', '')::int,
    nullif(p_payload->>'natureza_operacao', ''),
    nullif(p_payload->>'emitente_cnpj', ''),
    nullif(p_payload->>'emitente_nome', ''),
    nullif(p_payload->>'emitente_ie', ''),
    nullif(p_payload->>'destinatario_cnpj', ''),
    nullif(p_payload->>'destinatario_nome', ''),
    nullif(p_payload->>'valor_total', '')::numeric,
    nullif(p_payload->>'valor_produtos', '')::numeric,
    nullif(p_payload->>'valor_frete', '')::numeric,
    nullif(p_payload->>'valor_ipi', '')::numeric,
    nullif(p_payload->>'valor_icms', '')::numeric,
    coalesce(p_payload->'itens', '[]'::jsonb),
    v_xml
  )
  on conflict (chave) do update set
    orca_id = excluded.orca_id,
    numero = excluded.numero,
    serie = excluded.serie,
    data_emissao = excluded.data_emissao,
    tp_nf = excluded.tp_nf,
    natureza_operacao = excluded.natureza_operacao,
    emitente_cnpj = excluded.emitente_cnpj,
    emitente_nome = excluded.emitente_nome,
    emitente_ie = excluded.emitente_ie,
    destinatario_cnpj = excluded.destinatario_cnpj,
    destinatario_nome = excluded.destinatario_nome,
    valor_total = excluded.valor_total,
    valor_produtos = excluded.valor_produtos,
    valor_frete = excluded.valor_frete,
    valor_ipi = excluded.valor_ipi,
    valor_icms = excluded.valor_icms,
    itens = excluded.itens,
    xml = excluded.xml
  returning id into v_id;

  return (select to_jsonb(n) from nota_fiscal n where n.id = v_id);
end;
$$;

-- Exclui uma NF. Só admin da empresa.
create or replace function public.nota_fiscal_excluir(p_user_id bigint, p_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin_empresa(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;
  delete from nota_fiscal where id = p_id;
  return jsonb_build_object('ok', true);
end;
$$;

-- NFs vinculadas a um pedido (quem pode ver a orca pode ver as NFs).
create or replace function public.nota_fiscal_por_orca(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_pode_ver_orca(p_user_id, p_orca_id) then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(n) order by n.created_at asc, n.id asc)
    from nota_fiscal n where n.orca_id = p_orca_id
  ), '[]'::jsonb);
end;
$$;
