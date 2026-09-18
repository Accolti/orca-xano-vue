// Get Tipo_Variacao record
query "tipo_variacao/{tipo_variacao_id}" verb=GET {
  api_group = "Default"

  input {
    int tipo_variacao_id? filters=min:1
  }

  stack {
    db.get Tipo_Variacao {
      field_name = "id"
      field_value = $input.tipo_variacao_id
    } as $tipo_variacao
  
    precondition ($tipo_variacao != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $tipo_variacao
  guid = "IfQCYCoRbu1YvkGMk36o7qGt2qs"
}