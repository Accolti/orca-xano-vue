-- =============================================================
-- Fase 2B — Recálculo dinâmico do orçamento (port de Orcamento_Recalcular_Totais)
-- =============================================================

create or replace function public.orcamento_recalcular_totais(
  p_orca_id bigint,
  p_new_margem numeric default null,
  p_frt_b2b numeric default 0
)
returns jsonb
language plpgsql
as $$
declare
  v_orca orca%rowtype;
  v_desconto numeric;
  v_frt_b2c numeric;
  v_mao_de_obra numeric;
  v_markup_alvo numeric;
  v_total_custo_nota numeric;
  v_frete_b2b_total numeric;
  v_cst_tot numeric;
  v_venda_bruta_tot numeric;
  v_vnd_tot numeric;
  v_luc_tot numeric;
  v_markup_efetivo numeric;
  v_margem_real_total numeric;
  v_vlr_st_tot numeric;
  v_valor_difal_tot numeric;
  v_vlr_credito_icms_tot numeric;
  v_vlr_custo_fiscal_tot numeric;
  v_vlr_ipi_tot numeric;
  v_total_itens int;
  v_orca_json jsonb;
  v_itemS jsonb;
  v_totais jsonb;
begin
  select * into v_orca from orca where id = p_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if v_orca.eh_pedido is true then
    raise exception 'Orçamento convertido em pedido. Recálculo bloqueado.' using errcode = 'P0001';
  end if;

  v_desconto := coalesce(v_orca.desconto, 0);
  v_frt_b2c := coalesce(v_orca.frt_b2c, 0);
  v_mao_de_obra := coalesce(v_orca.mao_de_obra, 0);
  v_markup_alvo := coalesce(p_new_margem, v_orca.margem, 0);
  if v_markup_alvo <= 0 then
    v_markup_alvo := coalesce(v_orca.margem, 0);
  end if;

  -- 1. soma dos custos_nota (base do frete B2B)
  -- fallback "||" do Xano: vlr_cst_nota_unit || vlr_cst_unit_ipi || vlr_cst_unit
  select coalesce(
    sum(coalesce(nullif(vlr_cst_nota_unit, 0), nullif(vlr_cst_unit_ipi, 0), nullif(vlr_cst_unit, 0), 0) * coalesce(qtd, 1)),
    0
  ) into v_total_custo_nota from item where orca_id = p_orca_id;

  -- 2. frete B2B (Kapazi)
  v_frete_b2b_total := case
    when v_total_custo_nota >= 1000 then 0
    when v_total_custo_nota >= 300 then round(v_total_custo_nota * 0.10, 2)
    when v_total_custo_nota <= 0 then 0
    else coalesce(nullif(p_frt_b2b, 0), 50)
  end;

  -- 3. valores base por item
  create temp table _rec on commit drop as
  select
    i.id,
    coalesce(i.qtd, 1) as qtd,
    coalesce(nullif(i.vlr_cst_nota_unit, 0), nullif(i.vlr_cst_unit_ipi, 0), nullif(i.vlr_cst_unit, 0), 0) as cst_nota_unit,
    coalesce(i.valor_difal_unit, 0) as difal_unit,
    coalesce(i.vlr_credito_icms_unit, 0) as credito_unit,
    coalesce(i.vlr_st_unit, 0) as st_unit,
    coalesce(i.vlr_cst_unit_ipi, 0) as ipi_unit,
    0::numeric as frete_unit,
    0::numeric as custo_fiscal_unit,
    0::numeric as cst_entrada_unit,
    0::numeric as cst_entrada_total,
    0::numeric as venda_bruta_item,
    0::numeric as vnd_unit_bruto,
    0::numeric as vnd_unit,
    0::numeric as lucro_unit,
    0::numeric as perc_margem_real
  from item i where i.orca_id = p_orca_id;

  update _rec set
    frete_unit = case
      when v_total_custo_nota > 0
        then round((v_frete_b2b_total * (cst_nota_unit * qtd / v_total_custo_nota)) / qtd, 4)
      else 0
    end,
    custo_fiscal_unit = case
      when credito_unit > 0 then cst_nota_unit + st_unit - credito_unit
      else cst_nota_unit + st_unit + difal_unit
    end
  where true;

  update _rec set
    cst_entrada_unit = custo_fiscal_unit + frete_unit,
    cst_entrada_total = (custo_fiscal_unit + frete_unit) * qtd,
    venda_bruta_item = (custo_fiscal_unit + frete_unit) * qtd * (1 + v_markup_alvo / 100),
    vnd_unit_bruto = (custo_fiscal_unit + frete_unit) * qtd * (1 + v_markup_alvo / 100) / qtd
  where true;

  -- 4. totais
  select
    coalesce(sum(cst_entrada_total), 0),
    coalesce(sum(venda_bruta_item), 0),
    coalesce(sum(st_unit * qtd), 0),
    coalesce(sum(difal_unit * qtd), 0),
    coalesce(sum(credito_unit * qtd), 0),
    coalesce(sum(custo_fiscal_unit * qtd), 0),
    coalesce(sum(ipi_unit * qtd), 0),
    count(*)
  into
    v_cst_tot, v_venda_bruta_tot, v_vlr_st_tot, v_valor_difal_tot, v_vlr_credito_icms_tot,
    v_vlr_custo_fiscal_tot, v_vlr_ipi_tot, v_total_itens
  from _rec;

  v_vnd_tot := v_venda_bruta_tot - v_desconto;
  v_luc_tot := v_vnd_tot - v_cst_tot;
  v_markup_efetivo := case when v_cst_tot > 0 then (v_vnd_tot - v_cst_tot) / v_cst_tot * 100 else v_markup_alvo end;
  v_margem_real_total := case when v_vnd_tot > 0 then v_luc_tot / v_vnd_tot * 100 else 0 end;

  -- 5. rateio do desconto + venda líquida
  update _rec set
    vnd_unit = case
      when v_venda_bruta_tot > 0
        then round((venda_bruta_item - v_desconto * (venda_bruta_item / v_venda_bruta_tot)) / qtd, 4)
      else round(venda_bruta_item / qtd, 4)
    end
  where true;

  update _rec set
    lucro_unit = round(vnd_unit - cst_entrada_unit, 4),
    perc_margem_real = case when vnd_unit > 0 then round((vnd_unit - cst_entrada_unit) / vnd_unit * 100, 4) else 0 end
  where true;

  -- 6. atualiza itens
  update item i set
    vlr_cst_nota_unit = round(r.cst_nota_unit, 4),
    vlr_st_unit = round(r.st_unit, 4),
    vlr_custo_fiscal_unit = round(r.custo_fiscal_unit, 4),
    vlr_frete_b2b_unit = r.frete_unit,
    vlr_cst_entrada_unit = round(r.cst_entrada_unit, 4),
    vlr_vnd_unit = r.vnd_unit,
    vlr_vnd_unit_b2b = r.vnd_unit,
    vlr_vnd_unit_bruto = round(r.vnd_unit_bruto, 4),
    vlr_lucro_unit = r.lucro_unit,
    margem = round(v_markup_alvo, 4),
    perc_margem_real = r.perc_margem_real
  from _rec r where i.id = r.id;

  -- 7. atualiza o cabeçalho ORCA
  update orca set
    margem = round(v_markup_alvo, 4),
    markup_alvo = round(v_markup_alvo, 4),
    markup_efetivo = round(v_markup_efetivo, 4),
    venda_bruta_tot = round(v_venda_bruta_tot, 4),
    frt_b2b = round(v_frete_b2b_total, 4),
    cst_tot = round(v_cst_tot, 4),
    vnd_tot = round(v_vnd_tot, 4),
    luc_tot = round(v_luc_tot, 4),
    vnd_b2b_tot = round(v_vnd_tot, 4),
    vnd_b2b_b2c_tot = round(v_vnd_tot + v_frt_b2c + v_mao_de_obra, 4),
    vlr_st_tot = round(v_vlr_st_tot, 4),
    valor_difal_tot = round(v_valor_difal_tot, 4),
    vlr_credito_icms_tot = round(v_vlr_credito_icms_tot, 4),
    vlr_custo_fiscal_tot = round(v_vlr_custo_fiscal_tot, 4),
    vlr_ipi_tot = round(v_vlr_ipi_tot, 4),
    total_itens = v_total_itens
  where id = p_orca_id;

  -- 8. monta o retorno (ORCA_1 + itemS + totais)
  select to_jsonb(o) into v_orca_json from orca o where o.id = p_orca_id;

  select coalesce(jsonb_agg(
    to_jsonb(i) || jsonb_build_object('Descricao', concat_ws(' ', m.nome, l.nome, t.nome, n.nome, b.nome))
    order by i.id
  ), '[]'::jsonb)
  into v_itemS
  from item i
  join produto p on p.id = i.produto_id
  join material m on m.id = p.material_id
  left join linha l on l.id = p.linha_id
  left join tipo t on t.id = p.tipo_id
  left join nivel n on n.id = p.nivel_id
  left join borda b on b.id = i.borda_id
  where i.orca_id = p_orca_id;

  v_totais := jsonb_build_object(
    'cst_tot', round(v_cst_tot, 4),
    'venda_bruta_tot', round(v_venda_bruta_tot, 4),
    'vlr_st_tot', round(v_vlr_st_tot, 4),
    'valor_difal_tot', round(v_valor_difal_tot, 4),
    'vlr_credito_icms_tot', round(v_vlr_credito_icms_tot, 4),
    'vlr_custo_fiscal_tot', round(v_vlr_custo_fiscal_tot, 4),
    'vlr_ipi_tot', round(v_vlr_ipi_tot, 4),
    'vnd_tot', round(v_vnd_tot, 4),
    'luc_tot', round(v_luc_tot, 4),
    'vnd_B2B_tot', round(v_vnd_tot, 4),
    'vnd_B2B_B2C_tot', round(v_vnd_tot + v_frt_b2c + v_mao_de_obra, 4),
    'margem', round(v_markup_efetivo, 4),
    'markup_alvo', round(v_markup_alvo, 4),
    'markup_efetivo', round(v_markup_efetivo, 4),
    'margem_real_total', round(v_margem_real_total, 4),
    'frete_b2b_total', round(v_frete_b2b_total, 4),
    'desconto', round(v_desconto, 4),
    'frtB2C', round(v_frt_b2c, 4),
    'mao_de_obra', round(v_mao_de_obra, 4),
    'total_itens', v_total_itens
  );

  return jsonb_build_object('totais', v_totais, 'ORCA_1', v_orca_json, 'itemS', v_itemS);
end;
$$;
