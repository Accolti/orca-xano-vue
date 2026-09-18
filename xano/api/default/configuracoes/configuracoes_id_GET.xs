// Get Configuracoes record
query "configuracoes/{configuracoes_id}" verb=GET {
  api_group = "Default"

  input {
    int configuracoes_id? filters=min:1
  }

  stack {
    db.get Configuracoes {
      field_name = "id"
      field_value = $input.configuracoes_id
    } as $configuracoes
  
    precondition ($configuracoes != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $configuracoes
  guid = "Id6aa-e0gg0LkXgPZ8526QjtG08"
}