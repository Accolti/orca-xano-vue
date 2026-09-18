// Edit Unidade record
query "unidade/{unidade_id}" verb=POST {
  api_group = "Default"

  input {
    int unidade_id? filters=min:1
    dblink {
      table = "Unidade"
    }
  }

  stack {
    db.edit Unidade {
      field_name = "id"
      field_value = $input.unidade_id
      enforce_hidden_fields = false
      data = {}
    } as $unidade
  }

  response = $unidade
  guid = "tWF8qW9vGwWTVaVj_SQ2t2rXcfk"
}