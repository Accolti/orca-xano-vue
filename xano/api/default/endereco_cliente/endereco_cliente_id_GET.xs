// Get endereco_cliente record
query "endereco_cliente/{endereco_cliente_id}" verb=GET {
  api_group = "Default"

  input {
    int endereco_cliente_id? filters=min:1
  }

  stack {
    db.get Endereco_Cliente {
      field_name = "id"
      field_value = $input.endereco_cliente_id
    } as $endereco_cliente
  
    precondition ($endereco_cliente != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $endereco_cliente
  guid = "_BMMcxjK6cRdh6HDbnUUwVtfd9k"
}