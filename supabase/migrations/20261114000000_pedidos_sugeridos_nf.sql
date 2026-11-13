-- =============================================================
-- Sugestão de pedidos por valor (match com a NF).
-- Dado o valor da NF (sem frete), retorna os pedidos da empresa/árvore cujo
-- "Custo Kapazi" (Σ item.vlr_cst_nota_unit × qtd) esteja dentro da tolerância,
-- ordenados por proximidade.
-- =============================================================

create or replace function public.pedidos_sugeridos_nf(
  p_user_id bigint,
  p_valor numeric,
  p_tolerancia_pct numeric default 5
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_role text;
  v_empresa bigint;
  v_min numeric;
  v_max numeric;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin_empresa(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;

  v_min := coalesce(p_valor, 0) * (1 - coalesce(p_tolerancia_pct, 5) / 100.0);
  v_max := coalesce(p_valor, 0) * (1 + coalesce(p_tolerancia_pct, 5) / 100.0);

  select role into v_role from usuarios where id = p_user_id;
  v_empresa := f_empresa_id(p_user_id);

  return coalesce((
    select jsonb_agg(t order by t.diferenca_abs asc, t.id asc)
    from (
      select
        o.id,
        o.cod_orca,
        coalesce(c.nome_fantasia, c.razao_social) as cliente_nome,
        o.vnd_tot,
        round(coalesce(sum(i.vlr_cst_nota_unit * i.qtd), 0), 2) as custo_kapazi,
        round(abs(coalesce(sum(i.vlr_cst_nota_unit * i.qtd), 0) - coalesce(p_valor, 0)), 2) as diferenca_abs
      from orca o
      left join cliente c on c.id = o.cliente_id
      left join item i on i.orca_id = o.id
      where o.eh_pedido = true
        and (
          v_role = 'admin_geral'
          or o.user_id = v_empresa
          or o.user_id in (select f_descendentes(v_empresa))
        )
      group by o.id, c.nome_fantasia, c.razao_social
      having coalesce(sum(i.vlr_cst_nota_unit * i.qtd), 0) between v_min and v_max
      order by diferenca_abs asc, o.id asc
      limit 30
    ) t
  ), '[]'::jsonb);
end;
$$;
