// Login and retrieve an authentication token
query "auth/login" verb=POST {
  api_group = "Default"

  input {
    email email?
    text password?
  }

  stack {
    db.get User {
      field_name = "email"
      field_value = $input.email
      output = [
        "id"
        "created_at"
        "name"
        "name_first"
        "name_last"
        "email"
        "password"
        "frtB2B"
        "margem"
        "DiasVencimentoOrcamento"
        "organizacao_id"
        "razao"
        "fantasia"
        "cnpj"
        "ie"
        "cpf"
        "isPJ"
        "ativo"
      ]
    } as $user
  
    precondition ($user != null) {
      error_type = "accessdenied"
      error = "Invalid Credentials."
    }
  
    security.check_password {
      text_password = $input.password
      hash_password = $user.password
    } as $pass_result
  
    precondition ($pass_result) {
      error_type = "accessdenied"
      error = "Invalid Credentials."
    }
  
    // Usuário (ou um "pai" na hierarquia) desativado não pode entrar
    function.run f_ativo_efetivo {
      input = {user_id: $user.id}
    } as $ativoEfetivo
  
    precondition ($ativoEfetivo) {
      error_type = "accessdenied"
      error = "Conta inativa. Fale com o administrador."
    }
  
    security.create_auth_token {
      table = "User"
      extras = {}
      expiration = 86400
      id = $user.id
    } as $authToken
  }

  response = {authToken: $authToken, user: $user}
  guid = "1dkuhTkPjraXDT_6an_pUD8KCwI"
}