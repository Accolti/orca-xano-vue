// Get Boleto record
query "boleto/{boleto_id}" verb=GET {
  api_group = "Default"

  input {
    int boleto_id? filters=min:1
  }

  stack {
    db.get Boleto {
      field_name = "id"
      field_value = $input.boleto_id
    } as $boleto
  
    precondition ($boleto != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $boleto
  guid = "mqKUFFrbAe5PIwVCyPNFZUMxzkc"
}