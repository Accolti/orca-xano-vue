// Edit Lista record
query "lista/{lista_id}" verb=POST {
  api_group = "Default"

  input {
    int lista_id? filters=min:1
    dblink {
      table = ""
    }
  }

  stack {
    db.edit "" {
      field_name = "id"
      field_value = $input.lista_id
      enforce_hidden_fields = false
      data = {}
    } as $lista
  }

  response = $lista
  guid = "Yvhc6O2D6XJ5O_0OEnicXkCuu1Y"
}