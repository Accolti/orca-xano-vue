// Edit acessorio record
query "acessorio/{acessorio_id}" verb=POST {
  api_group = "Default"

  input {
    int acessorio_id? filters=min:1
    dblink {
      table = "Acessorio"
    }
  }

  stack {
    db.edit Acessorio {
      field_name = "id"
      field_value = $input.acessorio_id
      enforce_hidden_fields = false
      data = {}
    } as $acessorio
  }

  response = $acessorio
  guid = "7v_6XDY5SUyRBWVA09AE7xxXZA0"
}