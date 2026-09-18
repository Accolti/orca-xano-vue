// Delete Configuracoes record.
query "configuracoes/{configuracoes_id}" verb=DELETE {
  api_group = "Default"

  input {
    int configuracoes_id? filters=min:1
  }

  stack {
    db.del Configuracoes {
      field_name = "id"
      field_value = $input.configuracoes_id
    }
  }

  response = null
  guid = "S-_FhlzpptUjexbXbMKo9BZwwuQ"
}