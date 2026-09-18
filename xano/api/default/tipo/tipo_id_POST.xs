// Edit tipo record
query "tipo/{tipo_id}" verb=POST {
  api_group = "Default"

  input {
    int tipo_id? filters=min:1
    dblink {
      table = "Tipo"
    }
  }

  stack {
    db.edit Tipo {
      field_name = "id"
      field_value = $input.tipo_id
      enforce_hidden_fields = false
      data = {}
    } as $tipo
  }

  response = $tipo
  guid = "Gpkk6KZRh1AHmLdCMSab0FdI_Ac"
}