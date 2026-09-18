// Delete endereco_cliente record.
query "endereco_cliente/{endereco_cliente_id}" verb=DELETE {
  api_group = "Default"

  input {
    int endereco_cliente_id? filters=min:1
  }

  stack {
    db.del Endereco_Cliente {
      field_name = "id"
      field_value = $input.endereco_cliente_id
    }
  }

  response = null
  guid = "uE6bq4zksIfjrJdhu5PURaTFPS8"
}