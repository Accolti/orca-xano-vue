// Get cliente record
query "cliente/{cliente_id}" verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int cliente_id? filters=min:1
  }

  stack {
    db.get Cliente {
      field_name = "id"
      field_value = $input.cliente_id
      addon = [
        {
          name : "Endereco_Cliente"
          input: {cliente_id: $output.id}
          as   : "_endereco_cliente"
        }
        {
          name : "Telefone_Cliente_of_Cliente"
          input: {cliente_id: $output.id}
          as   : "_telefone_cliente_of_cliente"
        }
      ]
    } as $cliente
  
    precondition ($cliente != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $cliente
  guid = "gYayc2bdbPelC7YS0rYo0gdb0HM"
}