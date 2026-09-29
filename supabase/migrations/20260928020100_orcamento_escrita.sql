-- =============================================================
-- Fase 2B — Escrita do orçamento (perfil_efetivo, número, inserir/atualizar/deletar item)
-- =============================================================

-- Índice único do contador (evita duplicata em concorrência)
create unique index if not exists contador_user_id_key on public.contador (user_id);

-- Perfil efetivo (topo da cadeia vendedor_pai_id) — retorna o registro completo.
create or replace function public.perfil_efetivo(p_user_id bigint)
returns jsonb language sql stable as $$
  select to_jsonb(u) from usuarios u where u.id = f_empresa_id(p_user_id)
$$;

-- Gera o próximo cod_orca (contador por user_id, prefixo ORC).
create or replace function public.novo_numero_orcamento(p_user_id bigint)
returns jsonb language plpgsql as $$
declare
  v_nome text;
  v_contador contador%rowtype;
  v_num bigint;
  v_new_orca text;
begin
  select name into v_nome from usuarios where id = p_user_id;

  insert into contador (user_id, descricao, inicial, numero)
  values (p_user_id, v_nome, 'ORC', 9999)
  on conflict (user_id) do nothing;

  select * into v_contador from contador where user_id = p_user_id for update;
  v_num := coalesce(v_contador.numero, 9999) + 1;
  v_new_orca := coalesce(v_contador.inicial, 'ORC') || v_num;
  update contador set numero = v_num where id = v_contador.id;

  return jsonb_build_object('newOrca', v_new_orca);
end;
$$;

-- Inserir item (cria Orca na 1ª vez) + recalcula.
create or replace function public.orcamento_item_inserir(p_payload jsonb)
returns jsonb language plpgsql as $$
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
  -- resolve Orca por orca_id ou cod_orca (do próprio usuário)
  if v_orca_id > 0 then
    select * into v_orca from orca where id = v_orca_id;
  elsif v_cod_orca is not null then
    select * into v_orca from orca where cod_orca = v_cod_orca and user_id = v_user_id;
  end if;

  if v_orca.id is not null and v_orca.eh_pedido is true then
    raise exception 'Orçamento convertido em pedido. Edição bloqueada.' using errcode = 'P0001';
  end if;

  -- UF origem do fornecedor (organização)
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

  -- cria o item
  insert into item (
    created_at, orca_id, produto_id, ipi, imp, vlr_custo, base_calculo, und_produto, larg, comp,
    larg_fc, comp_fc, borda_id, vlr_cst_borda, und_borda, tipo_fator_id, detalhe_id,
    fator_de_corte_id, variacao_id, margem, qtd, vlr_cst_unit, vlr_cst_unit_ipi,
    vlr_cst_unit_imp, vlr_vnd_unit, vlr_vnd_unit_ipi, vlr_vnd_unit_imp, vlr_lucro_unit,
    vlr_vnd_unit_b2b, descricao, area_user, area_calc, vlr_cst_nota_unit, vlr_cst_entrada_unit,
    valor_difal_unit, vlr_credito_icms_unit, aliq_inter, aliq_interna, perc_difal,
    vlr_frete_b2b_unit, vlr_st_unit, vlr_custo_fiscal_unit, eh_importado, perc_margem_real,
    com_medida_exata, porcentagem_acrescimo, fc, detalhes_calculo
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
    p_payload->'detalhes_calculo'
  );

  -- recalcula
  v_recalc := orcamento_recalcular_totais(v_id_orca, null, coalesce((v_perfil->>'frt_b2b')::numeric, 0));
  return v_recalc;
end;
$$;

-- Atualizar item existente + recalcula.
create or replace function public.orcamento_item_atualizar(p_payload jsonb)
returns jsonb language plpgsql as $$
declare
  v_user_id bigint := coalesce((p_payload->>'user_id')::bigint, 0);
  v_item_id bigint := coalesce((p_payload->>'item_id')::bigint, 0);
  v_item item%rowtype;
  v_perfil jsonb := perfil_efetivo(v_user_id);
  v_recalc jsonb;
begin
  select * into v_item from item where id = v_item_id;
  if not found then
    raise exception 'Item não encontrado.' using errcode = 'P0001';
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
    detalhes_calculo = p_payload->'detalhes_calculo'
  where id = v_item_id;

  update orca set condicoes_pagamento = '' where id = v_item.orca_id;

  v_recalc := orcamento_recalcular_totais(v_item.orca_id, null, coalesce((v_perfil->>'frt_b2b')::numeric, 0));
  return v_recalc;
end;
$$;

-- Deletar item + recalcula.
create or replace function public.orcamento_item_deletar(p_item_id bigint)
returns jsonb language plpgsql as $$
declare
  v_item item%rowtype;
  v_perfil jsonb;
  v_recalc jsonb;
begin
  select * into v_item from item where id = p_item_id;
  if not found then
    raise exception 'Item não encontrado.' using errcode = 'P0001';
  end if;

  delete from item where id = p_item_id;

  v_perfil := perfil_efetivo((select user_id from orca where id = v_item.orca_id));
  v_recalc := orcamento_recalcular_totais(v_item.orca_id, null, coalesce((v_perfil->>'frt_b2b')::numeric, 0));
  return v_recalc;
end;
$$;
