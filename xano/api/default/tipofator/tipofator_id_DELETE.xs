// Delete tipofator record.
query "tipofator/{tipofator_id}" verb=DELETE {
  api_group = "Default"

  input {
    int tipofator_id? filters=min:1
  }

  stack {
    db.del Tipo_Fator {
      field_name = "id"
      field_value = $input.tipofator_id
    }
  }

  response = null
  guid = "kqF34ztNJUqtxwID0jN6mWbfFso"
}