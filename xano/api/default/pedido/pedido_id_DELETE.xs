query "pedido/{pedido_id}" verb=DELETE {
  api_group = "Default"

  input {
    int pedido_id? filters=min:1
  }

  stack {
    db.del Pedido {
      field_name = "id"
      field_value = $input.pedido_id
    }
  }

  response = null
  guid = "gH7_MsX52gNsSOJ5zo9DhJ0kxDI"
}