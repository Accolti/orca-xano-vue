// Delete Teste record.
query "teste/{teste_id}" verb=DELETE {
  api_group = "Default"

  input {
    int teste_id? filters=min:1
  }

  stack {
    db.del Teste {
      field_name = "id"
      field_value = $input.teste_id
    }
  }

  response = null
  guid = "0pxk3J4bt4cqvBa94x7Tdq827KA"
}