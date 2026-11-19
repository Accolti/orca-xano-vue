-- =============================================================
-- Pedido mínimo nas promoções (fábrica).
--
-- Cada item de promoção pode exigir um pedido mínimo para liberar
-- o desconto:
--   - pedido_minimo_valor (R$)  → tapetes (ex.: R$ 1.500 na venda do pedido)
--   - pedido_minimo_rolos (int) → grama (ex.: 5 rolos fechados)
--
-- Abaixo do mínimo o preço NORMAL é usado; ao atingir, o desconto
-- é aplicado (a decisão é feita no orcamento_recalcular_totais).
-- =============================================================

alter table public.promocao_item
  add column if not exists pedido_minimo_valor numeric,
  add column if not exists pedido_minimo_rolos int;

-- Expõe os mínimos para o motor de precificação (produto_ctx).
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
    'valor', pi.valor,
    'pedido_minimo_valor', pi.pedido_minimo_valor,
    'pedido_minimo_rolos', pi.pedido_minimo_rolos,
    'data_fim', pr.data_fim
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

-- Listagem do admin (exibe os mínimos por item).
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
          'valor', pi.valor,
          'pedido_minimo_valor', pi.pedido_minimo_valor,
          'pedido_minimo_rolos', pi.pedido_minimo_rolos
        ) order by pi.id)
        from promocao_item pi where pi.promocao_id = pr.id
      ), '[]'::jsonb)
    ) order by pr.created_at desc)
    from promocao pr
  ), '[]'::jsonb);
end;
$$;

-- Salva os mínimos por item.
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
    insert into promocao_item (
      promocao_id, produto_id, variacao_id, borda_id, tipo, valor,
      pedido_minimo_valor, pedido_minimo_rolos
    ) values (
      v_id,
      nullif(v_item->>'produto_id', '')::bigint,
      nullif(v_item->>'variacao_id', '')::bigint,
      nullif(v_item->>'borda_id', '')::bigint,
      v_item_tipo,
      coalesce((v_item->>'valor')::numeric, 0),
      nullif(v_item->>'pedido_minimo_valor', '')::numeric,
      nullif(v_item->>'pedido_minimo_rolos', '')::int
    );
  end loop;

  return jsonb_build_object('id', v_id);
end;
$$;
