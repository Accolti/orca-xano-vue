-- =============================================================
-- Fase 2D — Lista de orçamentos (orca_por_cliente_busca + orcamento_status_lista)
-- =============================================================

-- Busca sem acento/caixa (extensão contrib do Postgres; disponível no Supabase)
create extension if not exists unaccent;

-- Status de todas as orças do usuário (id + status), para a listagem.
create or replace function public.orcamento_status_lista(p_user_id bigint)
returns jsonb language sql stable as $$
  select coalesce(
    jsonb_agg(jsonb_build_object('id', o.id, 'status', o.status) order by o.id),
    '[]'::jsonb
  )
  from orca o
  where o.user_id = p_user_id
$$;

-- Lista paginada de orçamentos/pedidos do usuário, com busca e dados do cliente.
create or replace function public.orca_por_cliente_busca(
  p_user_id bigint,
  p_busca text default null,
  p_page int default 1,
  p_per_page int default 20,
  p_so_pedidos boolean default false,
  p_somente_orcamentos boolean default false
)
returns jsonb language plpgsql as $$
declare
  v_busca text := nullif(trim(coalesce(p_busca, '')), '');
  v_busca_norm text := nullif(unaccent(lower(v_busca)), '');
  v_busca_num text := nullif(regexp_replace(v_busca, '[^0-9]', '', 'g'), '');
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_per int := greatest(coalesce(p_per_page, 20), 1);
  v_offset int := (v_page - 1) * v_per;
  v_total int;
  v_items jsonb;
  v_items_received int;
begin
  create temp table _lista on commit drop as
  select
    o.id, o.created_at, o.cod_orca, o.cliente_id, o.frt_b2b, o.frt_b2c, o.validade,
    o.user_id, o.margem, o.cst_tot, o.luc_tot, o.vnd_tot, o.vnd_b2b_tot, o.vnd_b2b_b2c_tot,
    o.desconto, o.eh_pedido, o.status, o.data_envio, o.data_aprovacao, o.total_itens, o.mao_de_obra,
    c.nome_fantasia, c.razao_social, c.contato, c.cpf, c.cnpj, c.inscricao_estadual
  from orca o
  left join cliente c on c.id = o.cliente_id
  where o.user_id = p_user_id
    and (
      (p_so_pedidos and o.eh_pedido = true)
      or (p_somente_orcamentos and o.eh_pedido is not true)
      or ((p_so_pedidos is not true) and (p_somente_orcamentos is not true))
    )
    and (
      v_busca_norm is null
      or unaccent(lower(coalesce(o.cod_orca, ''))) like '%' || v_busca_norm || '%'
      or unaccent(lower(coalesce(c.nome_fantasia, ''))) like '%' || v_busca_norm || '%'
      or unaccent(lower(coalesce(c.razao_social, ''))) like '%' || v_busca_norm || '%'
      or unaccent(lower(coalesce(c.contato, ''))) like '%' || v_busca_norm || '%'
      or (
        v_busca_num is not null and v_busca_num <> ''
        and (
          regexp_replace(coalesce(c.cnpj, ''), '[^0-9]', '', 'g') like '%' || v_busca_num || '%'
          or regexp_replace(coalesce(c.cpf, ''), '[^0-9]', '', 'g') like '%' || v_busca_num || '%'
          or regexp_replace(coalesce(c.inscricao_estadual, ''), '[^0-9]', '', 'g') like '%' || v_busca_num || '%'
        )
      )
      or (o.cliente_id is not null and o.cliente_id::text = v_busca)
    );

  select count(*) into v_total from _lista;

  select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_items
  from (select * from _lista order by created_at desc, id desc limit v_per offset v_offset) t;

  v_items_received := coalesce(jsonb_array_length(v_items), 0);

  return jsonb_build_object(
    'itemsReceived', v_items_received,
    'curPage', v_page,
    'nextPage', case when v_offset + v_per < v_total then v_page + 1 else null end,
    'prevPage', case when v_page > 1 then v_page - 1 else null end,
    'offset', v_offset,
    'itemsTotal', v_total,
    'pageTotal', case when v_per > 0 then ceil(v_total::numeric / v_per)::int else 0 end,
    'items', v_items
  );
end;
$$;
