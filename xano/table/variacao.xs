table Variacao {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int detalhe_id? {
      table = "Detalhe"
    }
  
    int tipo_variacao_id? {
      table = "Tipo_Variacao"
    }
  
    decimal comp?
    decimal larg?
    int modelo_id? {
      table = "Modelo"
    }
  
    // Largura x Comprimento 
    text LxC? filters=trim
  
    int qtd_kit?
    decimal valor_custo?
    decimal valor_rolo?
    int cor_id? {
      table = "Cor"
    }
  
    decimal ordem?
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  
    bool ativo?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree", field: [{name: "detalhe_id", op: "asc"}]}
  ]

  guid = "zwV1KibGqJo_q8St5RCYATzTvD8"
}