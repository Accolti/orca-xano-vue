// Login and retrieve an authentication token
query "auth/login" verb=POST {
  api_group = "Teste"

  input {
    email email?
    text password?
  }

  stack {
    db.get User {
      field_name = "email"
      field_value = $input.email
      output = ["id", "created_at", "name", "email", "password"]
    } as $User
  
    precondition ($user != null) {
      error = "Invalid Credentials."
    }
  
    security.check_password {
      text_password = $input.password
      hash_password = $User.password
    } as $pass_result
  
    precondition ($pass_result) {
      error = "Invalid Credentials."
    }
  
    security.create_auth_token {
      table = "User"
      extras = {}
      expiration = 86400
      id = $User.id
    } as $authToken
  }

  response = {authToken: $authToken}
  guid = "OJFNmJF-nVkdMN4a3lzo17JhVfs"
}