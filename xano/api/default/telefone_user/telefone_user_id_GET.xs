// Get telefone_user record
query "telefone_user/{telefone_user_id}" verb=GET {
  api_group = "Default"

  input {
    int telefone_user_id? filters=min:1
  }

  stack {
    db.get telefone_user {
      field_name = "id"
      field_value = $input.telefone_user_id
    } as $telefone_user
  
    precondition ($telefone_user != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $telefone_user
  guid = "9XVSbtTssuPbp2sdOGBGNSxhMqc"
}