// Get telefone_cliente record
query "telefone_cliente/{telefone_cliente_id}" verb=GET {
  api_group = "Default"

  input {
    int telefone_cliente_id? filters=min:1
  }

  stack {
    db.get Telefone_Cliente {
      field_name = "id"
      field_value = $input.telefone_cliente_id
    } as $telefone_cliente
  
    precondition ($telefone_cliente != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $telefone_cliente
  guid = "y7zSsgulkOmbJhFABhHrfH4Smjo"
}