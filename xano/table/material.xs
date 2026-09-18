table Material {
  auth = false

  schema {
    int id
    text nome filters=trim
  
    // prioridade para ordenação
    decimal Ordenacao?
  
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int material_id? {
      table = "Material"
    }
  
    bool ativo?=true
    text descricao? filters=trim
  
    // Tempo de garantia em meses
    int garantia?
  
    text ncm? filters=trim
  
    // Imposto
    decimal imp?
  
    decimal ipi?
    decimal peso?
    int regra_fiscal_id?=1 {
      table = "Regra_Fiscal"
    }
  
    bool st?
  
    // % de MVA da Kapazi/SEFAZ (ex: 40.0 para 40%).
    decimal mva_padrao?
  
    // % da alíquota interna ICMS do destino de referência (ex: 18.0 para 18%).
    decimal aliq_st_interna?
  
    bool nac?
    text Observacao? filters=trim
  
    // se é importado ou não
    bool importado?
  
    int organizacao_id? {
      table = "Organizacao"
    }
  
    timestamp? updated_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      name : "material_search"
      lang : "portuguese"
      type : "search"
      field: [{name: "nome", op: "A"}, {name: "descricao", op: "B"}]
    }
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
  ]

  guid = "rQKs5xTYnDCNre0_btRJHpYC3Ow"
}