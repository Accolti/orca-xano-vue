// Get Provedor record
query "provedor/{provedor_id}" verb=GET {
  api_group = "Default"

  input {
    int provedor_id? filters=min:1
  }

  stack {
    db.get Provedor {
      field_name = "id"
      field_value = $input.provedor_id
    } as $provedor
  
    precondition ($provedor != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $provedor
  guid = "Y53yBDbDJSxeC0xUe7WC6Ln68B0"
}