table Cliente {
  auth = false

  schema {
    int id
    text tipo_pessoa? filters=trim
    text razao_social? filters=trim
    text nome_fantasia? filters=trim
    text contato? filters=trim
    text cpf? filters=trim
    text nome_cpf? filters=trim
    text cnpj? filters=trim
    text inscricao_estadual? filters=trim
    email "e-mail"?
    bool contribui_icms?
    bool isento?
    text observacao? filters=trim
    int user_id? {
      table = "User"
    }
  
    int beneficio_fiscal_id? {
      table = "Beneficio_Fiscal"
    }
  
    int mercado_id? {
      table = "Mercado"
    }
  
    int ramo_id? {
      table = "Ramo"
    }
  
    int regime_id? {
      table = "Regime"
    }
  
    timestamp created_at?=now {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
  ]

  guid = "0EcJH3tHzsyYtReBxEWBNyg9ra8"
}