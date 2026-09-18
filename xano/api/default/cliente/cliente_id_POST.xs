// Edit cliente record
query "cliente/{cliente_id}" verb=POST {
  api_group = "Default"

  input {
    int cliente_id? filters=min:1
    dblink {
      table = "Cliente"
    }
  }

  stack {
    db.edit Cliente {
      field_name = "id"
      field_value = $input.cliente_id
      enforce_hidden_fields = false
      data = {}
    } as $cliente
  }

  response = $cliente
  guid = "nTQrkSSLAEGMke_EIxtzY6iJlFs"
}