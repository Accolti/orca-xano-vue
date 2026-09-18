// Itens de ORCA
table item {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int orca_id? {
      table = "Orca"
    }
  
    int produto_id? {
      table = "Produto"
    }
  
    decimal? ipi?
    decimal? imp?
  
    // Valor da materia prima - o que está no catalogo
    decimal vlr_custo?
  
    text base_calculo? filters=trim|upper
    text und_produto? filters=trim
    decimal larg?
    decimal comp?
    decimal larg_fc?
    decimal comp_fc?
    int borda_id? {
      table = "Borda"
    }
  
    decimal? vlr_cst_borda?
    text? und_borda? filters=trim
    int tipo_fator_id? {
      table = "Tipo_Fator"
    }
  
    int detalhe_id? {
      table = "Detalhe"
    }
  
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  
    int variacao_id? {
      table = "Variacao"
    }
  
    // Margem cadastrada/desejada (%). Ex 85.50
    decimal margem?
  
    decimal qtd?
  
    // qUANDO É ML (PARA GRAMA) O VALOR DESTE CUSTO É EM Ml OU SEJA P m2 X 2 POIS O ROLO TEM 2M DE LARGURA.
    decimal vlr_cst_unit?
  
    decimal? vlr_cst_unit_ipi?
    decimal? vlr_cst_unit_imp?
  
    // Preço de venda unitário final - Este campo já tem incluido o valor das taxas ele é feito em outro processo. Não somar os impostos novamente.
    decimal vlr_vnd_unit?
  
    // vlr_vnd_unit * %ipi Ex 100 * 5% (ipi) nessa campo  fica registrado 5,00
    decimal? vlr_vnd_unit_ipi?
  
    decimal? vlr_vnd_unit_imp?
  
    // Lucro em R$ por unidade
    decimal vlr_lucro_unit?
  
    // Este campo já tem incluido o valor das taxas ele é feito em outro processo. Não somas os impostos novamente.
    decimal vlr_vnd_unit_b2b?
  
    // Preço cheio unitário antes do desconto — custo_entrada × (1 + markup_alvo/100). Auditoria.
    decimal vlr_vnd_unit_bruto?
  
    text descricao? filters=trim
    decimal area_user?
    decimal area_calc?
  
    // Custo do item na NF (Produto + IPI) --- SEM FRETE
    decimal vlr_cst_nota_unit?
  
    // Custo real de entrada com frete -> Custo de entrada = vlr_cst_nota + DIFAL − crédito ICMS
    decimal vlr_cst_entrada_unit?
  
    // DIFAL unitário aplicado - Componentes fiscais fixos do item (independentes do frete)
    decimal valor_difal_unit?
  
    // Crédito de ICMS unitário
    decimal vlr_credito_icms_unit?
  
    // Alíquota_interestadual_aplicada_na_entrada Ex 12
    decimal aliq_inter?
  
    // Alíquota interna do estado de destino aplicada (ex: 18.00)
    decimal aliq_interna?
  
    // (Decimal): Percentual do DIFAL aplicado (ex: 6.00).
    decimal perc_difal?
  
    // Frete B2B rateado por unidade 
    decimal vlr_frete_b2b_unit?
  
    decimal vlr_st_unit?
  
    // O resultado puro do Módulo Precificação (custo_nota + difal - credito) antes de somar o frete B2B do carrinho - Custo de aquisição fiscal
    decimal vlr_custo_fiscal_unit?
  
    // Identifica se a operação geral considerou alíquota interestadual reduzida (4%). OK
    bool eh_importado?
  
    // Margem real atingida (%)
    decimal perc_margem_real?
  
    // Medida exata (marcada pelo vendedor): acréscimo aplicado no custo de fábrica
    bool com_medida_exata?
  
    // Percentual de acréscimo aplicado (vem do Produto.porcentagem_acrescimo)
    decimal porcentagem_acrescimo?
  
    decimal[] fc?
  
    // Detalhes do cálculo de produtos compostos (ex.: PLAYKAP) e/ou ML, em JSON.
    // Ex.: { "playkap": { "placas": 35, "rampas_macho": 6, "rampas_femea": 6, "cantoneiras": 4 },
    //        "ml": { "rolos": 2, "metros_fracionados": 5, "orientacao": "...", "largura_fixa": 1.2 } }
    json detalhes_calculo?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "XXLLdgBNCZ1Rgi9GwDR9LODNt5Q"
}