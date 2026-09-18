// Get Transportadora record
query "transportadora/{transportadora_id}" verb=GET {
  api_group = "Default"

  input {
    int transportadora_id? filters=min:1
  }

  stack {
    db.get "" {
      field_name = "id"
      field_value = $input.transportadora_id
    } as $transportadora
  
    precondition ($transportadora != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $transportadora
  guid = "CqR0mvGZ8hRpM4gilSrQ-xvxHJ4"
}