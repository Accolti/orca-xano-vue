// Delete Provedor record.
query "provedor/{provedor_id}" verb=DELETE {
  api_group = "Default"

  input {
    int provedor_id? filters=min:1
  }

  stack {
    db.del Provedor {
      field_name = "id"
      field_value = $input.provedor_id
    }
  }

  response = null
  guid = "Fuhe31JjsgJZYh7D5CN6vL-eCr0"
}