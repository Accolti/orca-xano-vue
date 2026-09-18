// Itens de ORCA
table item_ped {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int pedido_id? {
      table = "Pedido"
    }
  
    int produto_id? {
      table = "Produto"
    }
  
    decimal ipi?
    decimal imp?
    decimal vlr_custo?
    text und_produto? filters=trim
    decimal larg?
    decimal comp?
    decimal larg_fc?
    decimal comp_fc?
    int borda_id? {
      table = "Borda"
    }
  
    decimal vlr_cst_borda?
    text und_borda? filters=trim
    int tipo_fator_id? {
      table = "Tipo_Fator"
    }
  
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  
    int detalhe_id? {
      table = "Detalhe"
    }
  
    int variacao_id? {
      table = "Variacao"
    }
  
    decimal margem?
    int qtd?
    decimal vlr_cst_unit?
    decimal vlr_cst_tot?
    decimal vlr_cst_unit_ipi?
    decimal vlr_cst_tot_ipi?
    decimal vlr_cst_unit_imp?
    decimal vlr_cst_tot_imp?
  
    // Este campo já tem incluido o valor das taxas ele é feito em outro processo. Não somas os impostos novamente.
    decimal vlr_vnd_unit?
  
    decimal vlr_vnd_tot?
    decimal vlr_vnd_unit_ipi?
    decimal vlr_vnd_tot_ipi?
    decimal vlr_vnd_unit_imp?
    decimal vlr_vnd_tot_imp?
  
    // Este campo já tem incluido o valor das taxas ele é feito em outro processo. Não somas os impostos novamente.
    decimal vlr_vnd_unit_b2b?
  
    decimal vlr_vnd_tot_b2b?
    text descricao? filters=trim
    decimal area_user?
    decimal area_calc?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "8iCJua8_mv-7WmRuR1yN08glifU"
}