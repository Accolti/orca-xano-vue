// Delete tipo record.
query "tipo/{tipo_id}" verb=DELETE {
  api_group = "Default"

  input {
    int tipo_id? filters=min:1
  }

  stack {
    db.del Tipo {
      field_name = "id"
      field_value = $input.tipo_id
    }
  }

  response = null
  guid = "AN5CyfJOXxPfsgwN5n8Vx8bA894"
}