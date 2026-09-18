// Get Contador record
query "contador/{contador_id}" verb=GET {
  api_group = "Default"

  input {
    int contador_id? filters=min:1
  }

  stack {
    db.get Contador {
      field_name = "id"
      field_value = $input.contador_id
    } as $contador
  
    precondition ($contador != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $contador
  guid = "k2rhJd3zJARqFXN87g-3Xdn84pA"
}