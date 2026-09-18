// Edit Contador record
query "contador/{contador_id}" verb=POST {
  api_group = "Default"

  input {
    int contador_id? filters=min:1
    dblink {
      table = "Contador"
    }
  }

  stack {
    db.edit Contador {
      field_name = "id"
      field_value = $input.contador_id
      enforce_hidden_fields = false
      data = {}
    } as $contador
  }

  response = $contador
  guid = "37hy1tI0r-dQCFg1Z4dxGdRARSs"
}