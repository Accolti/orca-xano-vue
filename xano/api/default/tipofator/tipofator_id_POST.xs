// Edit tipofator record
query "tipofator/{tipofator_id}" verb=POST {
  api_group = "Default"

  input {
    int tipofator_id? filters=min:1
    dblink {
      table = "Tipo_Fator"
    }
  }

  stack {
    db.edit Tipo_Fator {
      field_name = "id"
      field_value = $input.tipofator_id
      enforce_hidden_fields = false
      data = {}
    } as $tipofator
  }

  response = $tipofator
  guid = "Y8ytPtKGG8SqGc7lCaHPAtKCFtg"
}