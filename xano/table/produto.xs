table Produto {
  auth = false

  schema {
    int id
    int material_id? {
      table = "Material"
    }
  
    int linha_id? {
      table = "Linha"
    }
  
    int tipo_id? {
      table = "Tipo"
    }
  
    int nivel_id? {
      table = "Nivel"
    }
  
    int classificacao_id? {
      table = "Classificacao"
    }
  
    decimal valor?
  
    // Produtos com medida exata podem ter acrescimo no valor de custo pelo trabalho maior na confecção
    bool com_medida_exata?
  
    decimal porcentagem_acrescimo?
  
    // unidade de cobrança da empresa. Tabela: R$ 30 o m2
    enum Unidade?=M2 {
      values = ["M2", "ML", "Und", "Kit"]
    }
  
    // Aqui deve ser colocado qual é a base de calculo para o produto. Forma de calcular o custo do produto por m2, ml, kit etc
    enum Base_de_Calculo?=M2 {
      values = ["M2", "ML", "KIT", "UND", "COMPOSTO"]
    }
  
    // Para Base_de_Calculo = COMPOSTO: qual regra de composição aplicar (ex.: "playkap").
    // Vazio/nulo = sem composição.
    text tipo_composto? filters=trim
  
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int detalhe_id? {
      table = "Detalhe"
    }
  
    // Fator de corte fixo do produto (prioridade 1 no M2). Quando preenchido, o cálculo
    // usa direto esse Fator_de_Corte; senão cai no Tipo_Fator (material+linha+borda).
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  
    bool ativo?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {
      type : "btree|unique"
      field: [
        {name: "material_id", op: "asc"}
        {name: "classificacao_id", op: "asc"}
        {name: "linha_id", op: "asc"}
        {name: "tipo_id", op: "asc"}
        {name: "nivel_id", op: "asc"}
        {name: "detalhe_id", op: "asc"}
      ]
    }
  ]

  guid = "H4muKza7vbFUpxqh0FRMq9zvhhg"
}