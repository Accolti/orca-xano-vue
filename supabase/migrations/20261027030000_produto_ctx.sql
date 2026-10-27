-- Consolida os N lookups do motor de precificação (produto + material + regra_fiscal +
-- linha/tipo/nivel + borda + variação + fator de corte + promoções) num único RPC,
-- reduzindo round-trips do orcamento-calcular de ~10 para 1.
--
-- Retorna jsonb com os dados CRUS (sem aplicar a promoção — o override de custo fica
-- no motor JS, que já é testado). Chaves: produto, material, regra_fiscal, linha_nome,
-- tipo_nome, nivel_nome, borda, variacao, fator_de_corte_variacao, promos.

create or replace function public.produto_ctx(
  p_produto_id bigint,
  p_variacao_id bigint default null,
  p_borda_id bigint default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_produto jsonb;
  v_material jsonb;
  v_regra jsonb;
  v_linha_nome text;
  v_tipo_nome text;
  v_nivel_nome text;
  v_borda jsonb;
  v_variacao jsonb;
  v_fc jsonb;
  v_material_id bigint;
  v_regra_id bigint;
  v_promos jsonb;
begin
  select to_jsonb(p) into v_produto from produto p where p.id = p_produto_id;
  if v_produto is null then
    return null;
  end if;

  v_material_id := nullif(v_produto->>'material_id', '')::bigint;
  select to_jsonb(m) into v_material from material m where m.id = v_material_id;

  if v_material is not null and nullif(v_material->>'regra_fiscal_id', '')::bigint is not null then
    v_regra_id := nullif(v_material->>'regra_fiscal_id', '')::bigint;
    select to_jsonb(r) into v_regra from regra_fiscal r where r.id = v_regra_id;
  end if;

  if nullif(v_produto->>'linha_id', '')::bigint is not null then
    select nome into v_linha_nome from linha where id = nullif(v_produto->>'linha_id', '')::bigint;
  end if;
  if nullif(v_produto->>'tipo_id', '')::bigint is not null then
    select nome into v_tipo_nome from tipo where id = nullif(v_produto->>'tipo_id', '')::bigint;
  end if;
  if nullif(v_produto->>'nivel_id', '')::bigint is not null then
    select nome into v_nivel_nome from nivel where id = nullif(v_produto->>'nivel_id', '')::bigint;
  end if;

  if coalesce(p_borda_id, 0) > 0 then
    select to_jsonb(b) into v_borda from borda b where b.id = p_borda_id;
  end if;

  if coalesce(p_variacao_id, 0) > 0 then
    select to_jsonb(v) into v_variacao from variacao v where v.id = p_variacao_id;
    if v_variacao is not null and nullif(v_variacao->>'fator_de_corte_id', '')::bigint is not null then
      select to_jsonb(f) into v_fc from fator_de_corte f
      where f.id = nullif(v_variacao->>'fator_de_corte_id', '')::bigint;
    end if;
  end if;

  select promocoes_ativas(p_produto_id, p_variacao_id, p_borda_id) into v_promos;

  return jsonb_build_object(
    'produto', v_produto,
    'material', v_material,
    'regra_fiscal', v_regra,
    'linha_nome', v_linha_nome,
    'tipo_nome', v_tipo_nome,
    'nivel_nome', v_nivel_nome,
    'borda', v_borda,
    'variacao', v_variacao,
    'fator_de_corte_variacao', v_fc,
    'promos', v_promos
  );
end;
$$;
