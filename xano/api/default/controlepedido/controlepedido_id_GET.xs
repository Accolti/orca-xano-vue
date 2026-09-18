// Get ControlePedido record
query "controlepedido/{controlepedido_id}" verb=GET {
  api_group = "Default"

  input {
    int controlepedido_id? filters=min:1
  }

  stack {
    db.get "" {
      field_name = "id"
      field_value = $input.controlepedido_id
    } as $controlepedido
  
    precondition ($controlepedido != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $controlepedido
  guid = "4VyZPeHSVGA4XpxU1E1BV0F1z4I"
}