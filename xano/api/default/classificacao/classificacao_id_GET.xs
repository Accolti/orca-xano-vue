// Get classificacao record
query "classificacao/{classificacao_id}" verb=GET {
  api_group = "Default"

  input {
    int classificacao_id? filters=min:1
  }

  stack {
    db.get Classificacao {
      field_name = "id"
      field_value = $input.classificacao_id
    } as $classificacao
  
    precondition ($classificacao != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $classificacao
  guid = "_dZOdChdMv9NOcbNbxrBxSejN8g"
}