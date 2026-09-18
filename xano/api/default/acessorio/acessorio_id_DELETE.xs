// Delete acessorio record.
query "acessorio/{acessorio_id}" verb=DELETE {
  api_group = "Default"

  input {
    int acessorio_id? filters=min:1
  }

  stack {
    db.del Acessorio {
      field_name = "id"
      field_value = $input.acessorio_id
    }
  }

  response = null
  guid = "XSEYAePC3UPRO6nz9vtmOMFENXo"
}