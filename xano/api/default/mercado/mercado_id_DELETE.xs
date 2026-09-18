// Delete Mercado record.
query "mercado/{mercado_id}" verb=DELETE {
  api_group = "Default"

  input {
    int mercado_id? filters=min:1
  }

  stack {
    db.del Mercado {
      field_name = "id"
      field_value = $input.mercado_id
    }
  }

  response = null
  guid = "oW5W23npjCVlFDb1HG6u5quIhW8"
}