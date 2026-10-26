-- =============================================================
-- Promoções temporárias de custo (produto / variação / borda).
-- Global (todas as empresas); gerenciada só pelo admin_geral.
-- O motor de precificação (orcamento-calcular) sobrescreve o custo-base
-- durante o período, mantendo markup/frete/fiscal inalterados.
-- O tipo/valor ficam POR ITEM (cada produto/variação/borda tem seu desconto).
-- =============================================================

create table if not exists public.promocao (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  nome text not null,
  data_inicio date not null,
  data_fim date not null,
  ativo boolean not null default true
);

create table if not exists public.promocao_item (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  promocao_id bigint not null references public.promocao(id) on delete cascade,
  produto_id bigint references public.produto(id) on delete cascade,
  variacao_id bigint references public.variacao(id) on delete cascade,
  borda_id bigint references public.borda(id) on delete cascade,
  tipo text not null check (tipo in ('VALOR_FIXO', 'PERCENTUAL')),
  valor numeric not null default 0
);

create index if not exists promocao_item_produto_idx on public.promocao_item (produto_id);
create index if not exists promocao_item_variacao_idx on public.promocao_item (variacao_id);
create index if not exists promocao_item_borda_idx on public.promocao_item (borda_id);
create index if not exists promocao_item_promocao_idx on public.promocao_item (promocao_id);

alter table public.promocao enable row level security;
alter table public.promocao_item enable row level security;

-- ---------------------------------------------------------------------------
-- Promoções ativas no período que casam com produto/variação/borda.
-- Usada pelo motor de precificação (service role) e pelo front (selo).
-- ---------------------------------------------------------------------------
create or replace function public.promocoes_ativas(
  p_produto_id bigint default null,
  p_variacao_id bigint default null,
  p_borda_id bigint default null
)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'promocao_id', pr.id,
    'produto_id', pi.produto_id,
    'variacao_id', pi.variacao_id,
    'borda_id', pi.borda_id,
    'tipo', pi.tipo,
    'valor', pi.valor
  )), '[]'::jsonb)
  from promocao pr
  join promocao_item pi on pi.promocao_id = pr.id
  where pr.ativo = true
    and current_date >= pr.data_inicio
    and current_date <= pr.data_fim
    and (
      (p_produto_id is not null and pi.produto_id = p_produto_id)
      or (p_variacao_id is not null and pi.variacao_id = p_variacao_id)
      or (p_borda_id is not null and pi.borda_id = p_borda_id)
    );
$$;

-- ---------------------------------------------------------------------------
-- Admin (admin_geral): listar / salvar / excluir promoções.
-- ---------------------------------------------------------------------------
create or replace function public.promocao_listar(p_user_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_role text;
begin
  select role into v_role from usuarios where id = auth_user_id();
  if v_role is distinct from 'admin_geral' then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', pr.id,
      'nome', pr.nome,
      'data_inicio', pr.data_inicio,
      'data_fim', pr.data_fim,
      'ativo', pr.ativo,
      'itens', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', pi.id,
          'produto_id', pi.produto_id,
          'variacao_id', pi.variacao_id,
          'borda_id', pi.borda_id,
          'tipo', pi.tipo,
          'valor', pi.valor
        ) order by pi.id)
        from promocao_item pi where pi.promocao_id = pr.id
      ), '[]'::jsonb)
    ) order by pr.created_at desc)
    from promocao pr
  ), '[]'::jsonb);
end;
$$;

create or replace function public.promocao_salvar(p_user_id bigint, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_role text;
  v_id bigint := nullif(p_payload->>'id', '')::bigint;
  v_nome text := nullif(trim(p_payload->>'nome'), '');
  v_ini date := nullif(p_payload->>'data_inicio', '')::date;
  v_fim date := nullif(p_payload->>'data_fim', '')::date;
  v_ativo boolean := coalesce((p_payload->>'ativo')::boolean, true);
  v_item jsonb;
  v_item_tipo text;
begin
  select role into v_role from usuarios where id = auth_user_id();
  if v_role is distinct from 'admin_geral' then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if v_nome is null then
    raise exception 'Informe o nome da promoção.' using errcode = 'P0001';
  end if;
  if v_ini is null or v_fim is null or v_fim < v_ini then
    raise exception 'Período inválido.' using errcode = 'P0001';
  end if;

  if v_id is null then
    insert into promocao (nome, data_inicio, data_fim, ativo)
    values (v_nome, v_ini, v_fim, v_ativo)
    returning id into v_id;
  else
    update promocao set
      nome = v_nome,
      data_inicio = v_ini,
      data_fim = v_fim,
      ativo = v_ativo
    where id = v_id;
    if not found then
      raise exception 'Promoção não encontrada.' using errcode = 'P0001';
    end if;
  end if;

  delete from promocao_item where promocao_id = v_id;

  for v_item in select value from jsonb_array_elements(coalesce(p_payload->'itens', '[]'::jsonb)) loop
    v_item_tipo := v_item->>'tipo';
    if v_item_tipo not in ('VALOR_FIXO', 'PERCENTUAL') then
      continue;
    end if;
    insert into promocao_item (promocao_id, produto_id, variacao_id, borda_id, tipo, valor)
    values (
      v_id,
      nullif(v_item->>'produto_id', '')::bigint,
      nullif(v_item->>'variacao_id', '')::bigint,
      nullif(v_item->>'borda_id', '')::bigint,
      v_item_tipo,
      coalesce((v_item->>'valor')::numeric, 0)
    );
  end loop;

  return jsonb_build_object('id', v_id);
end;
$$;

create or replace function public.promocao_excluir(p_user_id bigint, p_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_role text;
begin
  select role into v_role from usuarios where id = auth_user_id();
  if v_role is distinct from 'admin_geral' then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  delete from promocao where id = p_id;
  return jsonb_build_object('ok', true);
end;
$$;
