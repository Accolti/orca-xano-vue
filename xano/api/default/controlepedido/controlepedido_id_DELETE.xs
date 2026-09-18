// Delete ControlePedido record.
query "controlepedido/{controlepedido_id}" verb=DELETE {
  api_group = "Default"

  input {
    int controlepedido_id? filters=min:1
  }

  stack {
    db.del ControlePedido {
      field_name = "id"
      field_value = $input.controlepedido_id
    }
  }

  response = $ControlePedido_1
  guid = "zzMWmzr3-XPd9wVe_SRHEGoGlHg"
}