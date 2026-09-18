// Edit Tipo_Variacao record
query "tipo_variacao/{tipo_variacao_id}" verb=POST {
  api_group = "Default"

  input {
    int tipo_variacao_id? filters=min:1
    dblink {
      table = "Tipo_Variacao"
    }
  }

  stack {
    db.edit Tipo_Variacao {
      field_name = "id"
      field_value = $input.tipo_variacao_id
      enforce_hidden_fields = false
      data = {}
    } as $tipo_variacao
  }

  response = $tipo_variacao
  guid = "lzXInmceHKae5wfXj36P9_4tKIM"
}