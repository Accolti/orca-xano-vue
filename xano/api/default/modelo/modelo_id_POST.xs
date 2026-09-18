// Edit Modelo record
query "modelo/{modelo_id}" verb=POST {
  api_group = "Default"

  input {
    int modelo_id? filters=min:1
    dblink {
      table = "Modelo"
    }
  }

  stack {
    db.edit Modelo {
      field_name = "id"
      field_value = $input.modelo_id
      enforce_hidden_fields = false
      data = {}
    } as $modelo
  }

  response = $modelo
  guid = "8YGT4mcuxNbhAHkJNrEcNizTN_s"
}