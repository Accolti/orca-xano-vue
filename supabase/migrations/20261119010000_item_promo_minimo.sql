-- =============================================================
-- Item: custo base sem promo + mínimos + rolos, para o recálculo
-- decidir se aplica o desconto da promoção conforme o pedido mínimo.
-- =============================================================

alter table public.item
  add column if not exists vlr_cst_nota_unit_base numeric,
  add column if not exists qtd_rolos int,
  add column if not exists promo_min_valor numeric,
  add column if not exists promo_min_rolos int,
  add column if not exists promo_aplicada boolean not null default false;

-- Itens legados já tinham a promoção "cozida" no detalhes_calculo.promo:
-- marca promo_aplicada = true para manter o selo/custo consistentes.
update public.item
  set promo_aplicada = true
  where coalesce((detalhes_calculo->'promo'->>'aplicada')::boolean, false) = true;

-- ---------------------------------------------------------------------------
-- Inserir item (security definer) persistindo os novos campos.
-- ---------------------------------------------------------------------------
create or replace function public.orcamento_item_inserir(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id bigint := coalesce((p_payload->>'user_id')::bigint, 0);
  v_orca_id bigint := coalesce((p_payload->>'orca_id')::bigint, 0);
  v_cod_orca text := nullif(p_payload->>'cod_orca', '');
  v_perfil jsonb := perfil_efetivo(v_user_id);
  v_org_id bigint := coalesce((v_perfil->>'organizacao_id')::bigint, 0);
  v_uf_origem text := 'PR';
  v_orca orca%rowtype;
  v_id_orca bigint := 0;
  v_recalc jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  if v_orca_id > 0 then
    select * into v_orca from orca where id = v_orca_id;
  elsif v_cod_orca is not null then
    select * into v_orca from orca where cod_orca = v_cod_orca and user_id = v_user_id;
  end if;

  if v_orca.id is not null and v_orca.user_id <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  if v_orca.id is not null and v_orca.eh_pedido is true then
    raise exception 'Orçamento convertido em pedido. Edição bloqueada.' using errcode = 'P0001';
  end if;

  if v_org_id > 0 then
    select coalesce(uf, 'PR') into v_uf_origem from organizacao where id = v_org_id;
  end if;

  if v_orca.id is null then
    insert into orca (
      created_at, cod_orca, cliente_id, frt_b2b, frt_b2c, validade, user_id, margem, desconto,
      observacao, status, eh_pedido, regime_id, uf_origem, uf_destino, markup_alvo
    ) values (
      now(),
      v_cod_orca,
      nullif(coalesce((p_payload->>'cliente_id')::bigint, 0), 0),
      coalesce((p_payload->>'frtB2B')::numeric, 0),
      coalesce((p_payload->>'frtB2C')::numeric, 0),
      nullif(p_payload->>'validade', '')::date,
      v_user_id,
      coalesce((p_payload->>'margem')::numeric, 0),
      0,
      p_payload->>'observacao',
      'RASCUNHO',
      false,
      nullif(coalesce((v_perfil->>'regime_id')::bigint, 0), 0),
      v_uf_origem,
      coalesce(nullif(v_perfil->>'uf', ''), 'SP'),
      coalesce((p_payload->>'margem')::numeric, 0)
    ) returning id into v_id_orca;
  else
    v_id_orca := v_orca.id;
    update orca set observacao = p_payload->>'observacao', condicoes_pagamento = '' where id = v_id_orca;
  end if;

  insert into item (
    created_at, orca_id, produto_id, ipi, imp, vlr_custo, base_calculo, und_produto, larg, comp,
    larg_fc, comp_fc, borda_id, vlr_cst_borda, und_borda, tipo_fator_id, detalhe_id,
    fator_de_corte_id, variacao_id, margem, qtd, vlr_cst_unit, vlr_cst_unit_ipi,
    vlr_cst_unit_imp, vlr_vnd_unit, vlr_vnd_unit_ipi, vlr_vnd_unit_imp, vlr_lucro_unit,
    vlr_vnd_unit_b2b, descricao, area_user, area_calc, vlr_cst_nota_unit, vlr_cst_entrada_unit,
    valor_difal_unit, vlr_credito_icms_unit, aliq_inter, aliq_interna, perc_difal,
    vlr_frete_b2b_unit, vlr_st_unit, vlr_custo_fiscal_unit, eh_importado, perc_margem_real,
    com_medida_exata, porcentagem_acrescimo, fc, detalhes_calculo,
    vlr_cst_nota_unit_base, qtd_rolos, promo_min_valor, promo_min_rolos, promo_aplicada
  ) values (
    now(),
    v_id_orca,
    coalesce((p_payload->>'produto_id')::bigint, 0),
    coalesce((p_payload->>'ipi')::numeric, 0),
    coalesce((p_payload->>'imp')::numeric, 0),
    coalesce((p_payload->>'vlr_custo')::numeric, 0),
    p_payload->>'base_calculo',
    p_payload->>'und_produto',
    coalesce((p_payload->>'larg')::numeric, 0),
    coalesce((p_payload->>'comp')::numeric, 0),
    coalesce((p_payload->>'larg_fc')::numeric, 0),
    coalesce((p_payload->>'comp_fc')::numeric, 0),
    nullif(coalesce((p_payload->>'borda_id')::bigint, 0), 0),
    coalesce((p_payload->>'vlr_cst_borda')::numeric, 0),
    p_payload->>'und_borda',
    nullif(coalesce((p_payload->>'tipo_fator_id')::bigint, 0), 0),
    nullif(coalesce((p_payload->>'detalhe_id')::bigint, 0), 0),
    nullif(coalesce((p_payload->>'fator_de_corte_id')::bigint, 0), 0),
    nullif(coalesce((p_payload->>'variacao_id')::bigint, 0), 0),
    coalesce((p_payload->>'margem')::numeric, 0),
    coalesce((p_payload->>'qtd')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_unit_ipi')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_unit_imp')::numeric, 0),
    coalesce((p_payload->>'vlr_vnd_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_vnd_unit_ipi')::numeric, 0),
    coalesce((p_payload->>'vlr_vnd_unit_imp')::numeric, 0),
    coalesce((p_payload->>'vlr_lucro_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_vnd_unit_b2b')::numeric, 0),
    p_payload->>'descricao',
    coalesce((p_payload->>'area_user')::numeric, 0),
    coalesce((p_payload->>'area_calc')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_nota_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_cst_entrada_unit')::numeric, 0),
    coalesce((p_payload->>'valor_difal_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_credito_icms_unit')::numeric, 0),
    coalesce((p_payload->>'aliq_inter')::numeric, 0),
    coalesce((p_payload->>'aliq_interna')::numeric, 0),
    coalesce((p_payload->>'perc_difal')::numeric, 0),
    coalesce((p_payload->>'vlr_frete_b2b_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_st_unit')::numeric, 0),
    coalesce((p_payload->>'vlr_custo_fiscal_unit')::numeric, 0),
    coalesce((p_payload->>'eh_importado')::boolean, false),
    coalesce((p_payload->>'perc_margem_real')::numeric, 0),
    coalesce((p_payload->>'com_medida_exata')::boolean, false),
    coalesce((p_payload->>'porcentagem_acrescimo')::numeric, 0),
    case when jsonb_typeof(p_payload->'fc') = 'array'
      then array(select elem::numeric from jsonb_array_elements_text(p_payload->'fc') as elem)
      else '{}'::numeric[] end,
    p_payload->'detalhes_calculo',
    nullif(p_payload->>'vlr_cst_nota_unit_base', '')::numeric,
    coalesce((p_payload->>'qtd_rolos')::int, 0),
    nullif(p_payload->>'promo_min_valor', '')::numeric,
    nullif(p_payload->>'promo_min_rolos', '')::int,
    coalesce((p_payload->>'promo_aplicada')::boolean, false)
  );

  v_recalc := orcamento_recalcular_totais(v_id_orca, null, coalesce((v_perfil->>'frt_b2b')::numeric, 0));
  return v_recalc;
end;
$$;

-- ---------------------------------------------------------------------------
-- Atualizar item (security definer) persistindo os novos campos.
-- ---------------------------------------------------------------------------
create or replace function public.orcamento_item_atualizar(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id bigint := coalesce((p_payload->>'user_id')::bigint, 0);
  v_item_id bigint := coalesce((p_payload->>'item_id')::bigint, 0);
  v_item item%rowtype;
  v_perfil jsonb := perfil_efetivo(v_user_id);
  v_recalc jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select * into v_item from item where id = v_item_id;
  if not found then
    raise exception 'Item não encontrado.' using errcode = 'P0001';
  end if;

  if (select user_id from orca where id = v_item.orca_id) <> v_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  update item set
    produto_id = coalesce((p_payload->>'produto_id')::bigint, 0),
    ipi = coalesce((p_payload->>'ipi')::numeric, 0),
    imp = coalesce((p_payload->>'imp')::numeric, 0),
    vlr_custo = coalesce((p_payload->>'vlr_custo')::numeric, 0),
    base_calculo = p_payload->>'base_calculo',
    und_produto = p_payload->>'und_produto',
    larg = coalesce((p_payload->>'larg')::numeric, 0),
    comp = coalesce((p_payload->>'comp')::numeric, 0),
    larg_fc = coalesce((p_payload->>'larg_fc')::numeric, 0),
    comp_fc = coalesce((p_payload->>'comp_fc')::numeric, 0),
    borda_id = nullif(coalesce((p_payload->>'borda_id')::bigint, 0), 0),
    vlr_cst_borda = coalesce((p_payload->>'vlr_cst_borda')::numeric, 0),
    und_borda = p_payload->>'und_borda',
    tipo_fator_id = nullif(coalesce((p_payload->>'tipo_fator_id')::bigint, 0), 0),
    fator_de_corte_id = nullif(coalesce((p_payload->>'fator_de_corte_id')::bigint, 0), 0),
    detalhe_id = nullif(coalesce((p_payload->>'detalhe_id')::bigint, 0), 0),
    variacao_id = nullif(coalesce((p_payload->>'variacao_id')::bigint, 0), 0),
    margem = coalesce((p_payload->>'margem')::numeric, 0),
    qtd = coalesce((p_payload->>'qtd')::numeric, 0),
    vlr_cst_unit = coalesce((p_payload->>'vlr_cst_unit')::numeric, 0),
    vlr_cst_unit_ipi = coalesce((p_payload->>'vlr_cst_unit_ipi')::numeric, 0),
    vlr_cst_unit_imp = coalesce((p_payload->>'vlr_cst_unit_imp')::numeric, 0),
    vlr_vnd_unit = coalesce((p_payload->>'vlr_vnd_unit')::numeric, 0),
    vlr_vnd_unit_ipi = coalesce((p_payload->>'vlr_vnd_unit_ipi')::numeric, 0),
    vlr_vnd_unit_imp = coalesce((p_payload->>'vlr_vnd_unit_imp')::numeric, 0),
    vlr_vnd_unit_b2b = coalesce((p_payload->>'vlr_vnd_unit_b2b')::numeric, 0),
    vlr_lucro_unit = coalesce((p_payload->>'vlr_lucro_unit')::numeric, 0),
    descricao = p_payload->>'descricao',
    area_user = coalesce((p_payload->>'area_user')::numeric, 0),
    area_calc = coalesce((p_payload->>'area_calc')::numeric, 0),
    vlr_cst_nota_unit = coalesce((p_payload->>'vlr_cst_nota_unit')::numeric, 0),
    vlr_cst_entrada_unit = coalesce((p_payload->>'vlr_cst_entrada_unit')::numeric, 0),
    valor_difal_unit = coalesce((p_payload->>'valor_difal_unit')::numeric, 0),
    vlr_credito_icms_unit = coalesce((p_payload->>'vlr_credito_icms_unit')::numeric, 0),
    aliq_inter = coalesce((p_payload->>'aliq_inter')::numeric, 0),
    aliq_interna = coalesce((p_payload->>'aliq_interna')::numeric, 0),
    perc_difal = coalesce((p_payload->>'perc_difal')::numeric, 0),
    vlr_frete_b2b_unit = coalesce((p_payload->>'vlr_frete_b2b_unit')::numeric, 0),
    vlr_st_unit = coalesce((p_payload->>'vlr_st_unit')::numeric, 0),
    vlr_custo_fiscal_unit = coalesce((p_payload->>'vlr_custo_fiscal_unit')::numeric, 0),
    eh_importado = coalesce((p_payload->>'eh_importado')::boolean, false),
    perc_margem_real = coalesce((p_payload->>'perc_margem_real')::numeric, 0),
    com_medida_exata = coalesce((p_payload->>'com_medida_exata')::boolean, false),
    porcentagem_acrescimo = coalesce((p_payload->>'porcentagem_acrescimo')::numeric, 0),
    fc = case when jsonb_typeof(p_payload->'fc') = 'array'
      then array(select elem::numeric from jsonb_array_elements_text(p_payload->'fc') as elem)
      else '{}'::numeric[] end,
    detalhes_calculo = p_payload->'detalhes_calculo',
    vlr_cst_nota_unit_base = nullif(p_payload->>'vlr_cst_nota_unit_base', '')::numeric,
    qtd_rolos = coalesce((p_payload->>'qtd_rolos')::int, 0),
    promo_min_valor = nullif(p_payload->>'promo_min_valor', '')::numeric,
    promo_min_rolos = nullif(p_payload->>'promo_min_rolos', '')::int,
    promo_aplicada = coalesce((p_payload->>'promo_aplicada')::boolean, false)
  where id = v_item_id;

  update orca set condicoes_pagamento = '' where id = v_item.orca_id;

  v_recalc := orcamento_recalcular_totais(v_item.orca_id, null, coalesce((v_perfil->>'frt_b2b')::numeric, 0));
  return v_recalc;
end;
$$;

-- ---------------------------------------------------------------------------
-- Duplicar orçamento (security definer) preservando os campos de promoção.
-- ---------------------------------------------------------------------------
create or replace function public.orcamento_duplicar(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_orca orca%rowtype;
  v_new_cod text;
  v_new_id bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_ativo_efetivo(p_user_id) then
    raise exception 'Conta inativa. Fale com o administrador.' using errcode = 'P0001';
  end if;

  select * into v_orca from orca where id = p_orca_id;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  if not f_dono_ou_admin(p_user_id, p_orca_id) then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  v_new_cod := (novo_numero_orcamento(p_user_id))->>'newOrca';

  insert into orca (
    created_at, cod_orca, cliente_id, frt_b2b, frt_b2c, validade, user_id, margem,
    markup_alvo, markup_efetivo, cst_tot, luc_tot, vnd_tot, vnd_b2b_tot, vnd_b2b_b2c_tot,
    venda_bruta_tot, desconto, mao_de_obra, vlr_st_tot, valor_difal_tot, vlr_credito_icms_tot,
    vlr_custo_fiscal_tot, vlr_ipi_tot, total_itens, observacao, condicoes_pagamento,
    condicoes_pagamento_params, regime_id, uf_origem, uf_destino,
    desconto_aprovado, desconto_status
  ) values (
    now(), v_new_cod, v_orca.cliente_id, v_orca.frt_b2b, v_orca.frt_b2c, v_orca.validade,
    p_user_id, v_orca.margem, v_orca.markup_alvo, v_orca.markup_efetivo, v_orca.cst_tot,
    v_orca.luc_tot, v_orca.vnd_tot, v_orca.vnd_b2b_tot, v_orca.vnd_b2b_b2c_tot,
    v_orca.venda_bruta_tot, v_orca.desconto, v_orca.mao_de_obra, v_orca.vlr_st_tot,
    v_orca.valor_difal_tot, v_orca.vlr_credito_icms_tot, v_orca.vlr_custo_fiscal_tot,
    v_orca.vlr_ipi_tot, v_orca.total_itens, v_orca.observacao, v_orca.condicoes_pagamento,
    v_orca.condicoes_pagamento_params, v_orca.regime_id, v_orca.uf_origem, v_orca.uf_destino,
    true, 'aprovado'
  ) returning id into v_new_id;

  insert into item (
    created_at, orca_id, produto_id, ipi, imp, vlr_custo, base_calculo, und_produto, larg, comp,
    larg_fc, comp_fc, borda_id, vlr_cst_borda, und_borda, tipo_fator_id, detalhe_id,
    fator_de_corte_id, variacao_id, margem, qtd, vlr_cst_unit, vlr_cst_unit_ipi,
    vlr_cst_unit_imp, vlr_vnd_unit, vlr_vnd_unit_ipi, vlr_vnd_unit_imp, vlr_lucro_unit,
    vlr_vnd_unit_b2b, descricao, area_user, area_calc, vlr_cst_nota_unit, vlr_cst_entrada_unit,
    valor_difal_unit, vlr_credito_icms_unit, aliq_inter, aliq_interna, perc_difal,
    vlr_frete_b2b_unit, vlr_st_unit, vlr_custo_fiscal_unit, eh_importado, perc_margem_real,
    com_medida_exata, porcentagem_acrescimo, fc, vlr_vnd_unit_bruto, detalhes_calculo,
    vlr_cst_nota_unit_base, qtd_rolos, promo_min_valor, promo_min_rolos, promo_aplicada
  )
  select now(), v_new_id, produto_id, ipi, imp, vlr_custo, base_calculo, und_produto, larg, comp,
    larg_fc, comp_fc, borda_id, vlr_cst_borda, und_borda, tipo_fator_id, detalhe_id,
    fator_de_corte_id, variacao_id, margem, qtd, vlr_cst_unit, vlr_cst_unit_ipi,
    vlr_cst_unit_imp, vlr_vnd_unit, vlr_vnd_unit_ipi, vlr_vnd_unit_imp, vlr_lucro_unit,
    vlr_vnd_unit_b2b, descricao, area_user, area_calc, vlr_cst_nota_unit, vlr_cst_entrada_unit,
    valor_difal_unit, vlr_credito_icms_unit, aliq_inter, aliq_interna, perc_difal,
    vlr_frete_b2b_unit, vlr_st_unit, vlr_custo_fiscal_unit, eh_importado, perc_margem_real,
    com_medida_exata, porcentagem_acrescimo, fc, vlr_vnd_unit_bruto, detalhes_calculo,
    vlr_cst_nota_unit_base, qtd_rolos, promo_min_valor, promo_min_rolos, promo_aplicada
  from item where orca_id = p_orca_id;

  return jsonb_build_object('orca', jsonb_build_object('cod_orca', v_new_cod, 'id', v_new_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- Recálculo dinâmico: decide o custo (promo vs normal) conforme o pedido mínimo
-- (valor ou rolos) e aplica o restante da cadeia (frete/markup/desconto).
-- ---------------------------------------------------------------------------
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
  v_total_rolos numeric;
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

  -- 1. total de rolos fechados (grama) — base do mínimo por rolos.
  select coalesce(sum(coalesce(qtd_rolos, 0)), 0) into v_total_rolos from item where orca_id = p_orca_id;

  -- 2. valores base por item (custo promocional + custo base sem promo + mínimos).
  create temp table _rec on commit drop as
  select
    i.id,
    coalesce(i.qtd, 1) as qtd,
    coalesce(nullif(i.vlr_cst_nota_unit, 0), nullif(i.vlr_cst_unit_ipi, 0), nullif(i.vlr_cst_unit, 0), 0) as cst_nota_promo,
    coalesce(
      nullif(i.vlr_cst_nota_unit_base, 0),
      coalesce(nullif(i.vlr_cst_nota_unit, 0), nullif(i.vlr_cst_unit_ipi, 0), nullif(i.vlr_cst_unit, 0), 0)
    ) as cst_nota_base,
    coalesce(i.valor_difal_unit, 0) as difal_unit,
    coalesce(i.vlr_credito_icms_unit, 0) as credito_unit,
    coalesce(i.vlr_st_unit, 0) as st_unit,
    coalesce(i.vlr_cst_unit_ipi, 0) as ipi_unit,
    coalesce(i.promo_min_valor, 0) as promo_min_valor,
    coalesce(i.promo_min_rolos, 0) as promo_min_rolos,
    coalesce((i.detalhes_calculo->'promo'->>'aplicada')::boolean, false) as tem_promo,
    false as promo_aplicada,
    0::numeric as cst_nota_unit,
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

  -- 3. decisão inicial do custo: rolos (definitivo) e valor (promo tentativa).
  update _rec set
    cst_nota_unit = case
      when promo_min_rolos > 0 then (case when v_total_rolos >= promo_min_rolos then cst_nota_promo else cst_nota_base end)
      when promo_min_valor > 0 then cst_nota_promo
      else cst_nota_promo
    end,
    promo_aplicada = case
      when promo_min_rolos > 0 then (v_total_rolos >= promo_min_rolos)
      when promo_min_valor > 0 then true
      else tem_promo
    end;

  -- 4. laço determinístico: calcula totais e, se o mínimo por valor não for
  --    atingido, reverte esses itens para o custo base (monotônico, só aumenta).
  for _pass in 1..3 loop
    select coalesce(sum(cst_nota_unit * qtd), 0) into v_total_custo_nota from _rec;

    v_frete_b2b_total := case
      when v_total_custo_nota >= 1000 then 0
      when v_total_custo_nota >= 300 then round(v_total_custo_nota * 0.10, 2)
      when v_total_custo_nota <= 0 then 0
      else coalesce(nullif(p_frt_b2b, 0), 50)
    end;

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

    -- Pedido mínimo por VALOR é sobre o custo Kapazi (Σ vlr_cst_nota_unit × qtd),
    -- já com a promo aplicada ("quanto vou pagar para a Kapazi").
    if not exists (
      select 1 from _rec where promo_min_valor > 0 and v_total_custo_nota < promo_min_valor
    ) then
      exit;
    end if;

    update _rec set
      cst_nota_unit = cst_nota_base,
      promo_aplicada = false
    where promo_min_valor > 0 and v_total_custo_nota < promo_min_valor;
  end loop;

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
    vlr_lucro_unit = r.lucro_unit,
    margem = round(v_markup_alvo, 4),
    perc_margem_real = r.perc_margem_real,
    promo_aplicada = r.promo_aplicada
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
    'total_rolos', v_total_rolos,
    'total_itens', v_total_itens
  );

  return jsonb_build_object('totais', v_totais, 'ORCA_1', v_orca_json, 'itemS', v_itemS);
end;
$$;
