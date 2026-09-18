// Edit Provedor record
query "provedor/{provedor_id}" verb=PATCH {
  api_group = "Default"

  input {
    int provedor_id? filters=min:1
    dblink {
      table = "Provedor"
    }
  }

  stack {
    util.get_raw_input {
      encoding = "json"
      exclude_middleware = false
    } as $raw_input
  
    db.patch Provedor {
      field_name = "id"
      field_value = $input.provedor_id
      data = `$input|pick:($raw_input|keys)`|filter_null|filter_empty_text
    } as $provedor
  }

  response = $provedor
  guid = "lChtsVuHJmPkiG1HYqoG9q4nPBE"
}