// Get Lista record
query "lista/{lista_id}" verb=GET {
  api_group = "Default"

  input {
    int lista_id? filters=min:1
  }

  stack {
    db.get "" {
      field_name = "id"
      field_value = $input.lista_id
    } as $lista
  
    precondition ($lista != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $lista
  guid = "GgH3bO2pDNb7qmaKc3EXAKCEmR8"
}