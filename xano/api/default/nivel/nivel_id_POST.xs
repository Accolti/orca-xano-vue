// Edit nivel record
query "nivel/{nivel_id}" verb=POST {
  api_group = "Default"

  input {
    int nivel_id? filters=min:1
    dblink {
      table = "Nivel"
    }
  }

  stack {
    db.edit Nivel {
      field_name = "id"
      field_value = $input.nivel_id
      enforce_hidden_fields = false
      data = {}
    } as $nivel
  }

  response = $nivel
  guid = "AzwVEsxUvXfnUAHdUrvOsg7Gf60"
}