// Get user record
query user_emal verb=GET {
  api_group = "Default"

  input {
    email email?
  }

  stack {
    db.get User {
      field_name = "email"
      field_value = $input.email
      addon = [
        {
          name : "Organizacao"
          input: {Organizacao_id: $output.organizacao_id}
          as   : "_organizacao"
        }
      ]
    } as $user
  
    precondition ($user != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $user
  guid = "7fyOal_baGwlB-mABSVQH7mx88I"
}