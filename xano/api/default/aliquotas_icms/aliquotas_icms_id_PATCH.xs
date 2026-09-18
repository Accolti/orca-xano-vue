// Edit Aliquotas_icms record
query "aliquotas_icms/{aliquotas_icms_id}" verb=PATCH {
  api_group = "Default"

  input {
    int aliquotas_icms_id? filters=min:1
    dblink {
      table = "Aliquotas_icms"
    }
  }

  stack {
    util.get_raw_input {
      encoding = "json"
      exclude_middleware = false
    } as $raw_input
  
    db.patch Aliquotas_icms {
      field_name = "id"
      field_value = $input.aliquotas_icms_id
      data = `$input|pick:($raw_input|keys)`|filter_null|filter_empty_text
    } as $aliquotas_icms
  }

  response = $aliquotas_icms
  guid = "1YeZA7J-hETE6m1g_PH4NbDE4xU"
}