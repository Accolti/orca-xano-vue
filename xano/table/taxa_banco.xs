// Taxas com valores de rapasse de taxa ao cliente
table Taxa_Banco {
  auth = false

  schema {
    int id
    int provedor_id? {
      table = "Provedor"
    }
  
    // Empresa dona da taxa (null = tabela global/default da Orca)
    int user_id? {
      table = "User"
    }
  
    // Canal de cobrança: cartao_link | cartao_celular | cartao_pos (null = genérico/todos)
    text canal? filters=trim
  
    // Numero de Parcelas
    int parcelas?
  
    // Taxa do cartão de predito por parcela
    decimal cc_taxa?
  
    // Origem do registro: manual | api | scrape
    text origem?=manual filters=trim
  
    bool ativo?=true
    timestamp atualizado_em?=now
    timestamp created_at?=now {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  tags = ["novo-sis"]
  guid = "LnCS1xgfGnPwms5AzCTijf_Najo"
}