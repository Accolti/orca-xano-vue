// Get Mercado record
query "mercado/{mercado_id}" verb=GET {
  api_group = "Default"

  input {
    int mercado_id? filters=min:1
  }

  stack {
    db.get Mercado {
      field_name = "id"
      field_value = $input.mercado_id
    } as $mercado
  
    precondition ($mercado != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $mercado
  guid = "BDsYjW-pYQLX827rzSkYFz8_UIs"
}