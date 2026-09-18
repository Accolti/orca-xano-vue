// Get user record
query "user/{user_id}" verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int user_id? {
      visibility = "internal"
    }
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
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
  guid = "yvPBUHB3IIs-jieFkKl_9mpJNmY"
}