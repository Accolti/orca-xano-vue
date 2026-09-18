// Delete Contador record.
query "contador/{contador_id}" verb=DELETE {
  api_group = "Default"

  input {
    int contador_id? filters=min:1
  }

  stack {
    db.del Contador {
      field_name = "id"
      field_value = $input.contador_id
    }
  }

  response = null
  guid = "tEJgSbEX5OnYrTziG0ygbF5zxfg"
}