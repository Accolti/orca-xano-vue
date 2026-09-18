// Get Variacao record
query "variacao/{variacao_id}" verb=GET {
  api_group = "Default"

  input {
    int variacao_id? filters=min:1
  }

  stack {
    db.get Variacao {
      field_name = "id"
      field_value = $input.variacao_id
    } as $variacao
  
    precondition ($variacao != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $variacao
  guid = "Fl685spEW8gnT3asQj3kOw_SEDY"
}