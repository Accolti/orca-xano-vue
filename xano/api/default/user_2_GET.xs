// Get user record
query user2 verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = [
        "id"
        "created_at"
        "name"
        "name_first"
        "name_last"
        "email"
        "frtB2B"
        "margem"
        "DiasVencimentoOrcamento"
        "organizacao_id"
      ]
    
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
  guid = "OcmTGlfQzZPxtRyjMuoOXAoQcV4"
}