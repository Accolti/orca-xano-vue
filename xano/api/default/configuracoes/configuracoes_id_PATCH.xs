// Edit Configuracoes record
query "configuracoes/{configuracoes_id}" verb=PATCH {
  api_group = "Default"

  input {
    int configuracoes_id? filters=min:1
    dblink {
      table = "Configuracoes"
    }
  }

  stack {
    util.get_raw_input {
      encoding = "json"
      exclude_middleware = false
    } as $raw_input
  
    db.patch Configuracoes {
      field_name = "id"
      field_value = $input.configuracoes_id
      data = `$input|pick:($raw_input|keys)`|filter_null|filter_empty_text
    } as $configuracoes
  }

  response = $configuracoes
  guid = "rRZsmgITYmqwKUEfZRTXNus48UM"
}