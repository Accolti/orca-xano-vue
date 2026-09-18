// Edit Mercado record
query "mercado/{mercado_id}" verb=POST {
  api_group = "Default"

  input {
    int mercado_id? filters=min:1
    dblink {
      table = "Mercado"
    }
  }

  stack {
    db.edit Mercado {
      field_name = "id"
      field_value = $input.mercado_id
      enforce_hidden_fields = false
      data = {}
    } as $mercado
  }

  response = $mercado
  guid = "CBNTRSGa6wU3D5MXudWF97ZqqEc"
}