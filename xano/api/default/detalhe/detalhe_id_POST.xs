// Edit Detalhe record
query "detalhe/{detalhe_id}" verb=POST {
  api_group = "Default"

  input {
    int detalhe_id? filters=min:1
    dblink {
      table = "Detalhe"
    }
  }

  stack {
    db.edit Detalhe {
      field_name = "id"
      field_value = $input.detalhe_id
      enforce_hidden_fields = false
      data = {}
    } as $detalhe
  }

  response = $detalhe
  guid = "sYoakcmz0XG9AmIlY9f-zkLKEgw"
}