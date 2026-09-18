// Get Modelo record
query "modelo/{modelo_id}" verb=GET {
  api_group = "Default"

  input {
    int modelo_id? filters=min:1
  }

  stack {
    db.get Modelo {
      field_name = "id"
      field_value = $input.modelo_id
    } as $modelo
  
    precondition ($modelo != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $modelo
  guid = "dsMAPDDEBcdbBhtykfDRSptaBxE"
}