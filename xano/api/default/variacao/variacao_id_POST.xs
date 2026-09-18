// Edit Variacao record
query "variacao/{variacao_id}" verb=POST {
  api_group = "Default"

  input {
    int variacao_id? filters=min:1
    dblink {
      table = "Variacao"
    }
  }

  stack {
    db.edit Variacao {
      field_name = "id"
      field_value = $input.variacao_id
      enforce_hidden_fields = false
      data = {}
    } as $variacao
  }

  response = $variacao
  guid = "wxRBc6H6tpQy_-F--Aqvkmz8528"
}