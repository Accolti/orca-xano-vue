query "pedido/{pedido_id}" verb=GET {
  api_group = "Default"

  input {
    int pedido_id? filters=min:1
  }

  stack {
    db.get Pedido {
      field_name = "id"
      field_value = $input.pedido_id
    } as $model
  
    precondition ($model != null) {
      error_type = "notfound"
      error = "Not Found"
    }
  }

  response = $model
  guid = "0RIwLEIz3r8n0HPyVv5T5QwL12s"
}