// Get Regime record
query "regime/{regime_id}" verb=GET {
  api_group = "Default"

  input {
    int regime_id? filters=min:1
  }

  stack {
    db.get Regime {
      field_name = "id"
      field_value = $input.regime_id
    } as $regime
  
    precondition ($regime != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $regime
  guid = "9_-ZWfnm9kxM193b5j0dLFXv9dI"
}