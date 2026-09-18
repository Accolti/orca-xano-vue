// Signup and retrieve an authentication token
query "auth/signup" verb=POST {
  api_group = "Default"

  input {
    email email?
    text password?
    text name_first? filters=trim
    text name_last? filters=trim
  }

  stack {
    // Cadastro por convite: só cria conta se o e-mail estiver na allowlist
    // (Cadastro_Autorizado) — o dono cadastra os convidados na tabela.
    db.query Cadastro_Autorizado {
      where = $db.Cadastro_Autorizado.email == $input.email
      return = {type: "list"}
    } as $autorizado
  
    precondition (($autorizado|count) > 0) {
      error_type = "accessdenied"
      error = "Cadastro por convite. Entre em contato para liberar seu acesso."
    }
  
    db.get User {
      field_name = "email"
      field_value = $input.email
    } as $user
  
    precondition ($user == null) {
      error_type = "accessdenied"
      error = "This account is already in use."
    }
  
    db.add User {
      enforce_hidden_fields = false
      data = {
        created_at             : "now"
        name                   : $input.name_first|concat:$input.name_last:" "
        name_first             : $input.name_first
        name_last              : $input.name_last
        email                  : $input.email
        password               : $input.password
        frtB2B                 : 0
        margem                 : 0
        DiasVencimentoOrcamento: ""
        organizacao_id         : "0"
        razao                  : ""
        fantasia               : ""
        cnpj                   : ""
        ie                     : ""
        cpf                    : ""
        isPJ                   : "1"
        logo                   : ""
        google_oauth           : ""
      }
    } as $user
  
    security.create_auth_token {
      table = "User"
      extras = {}
      expiration = 86400
      id = $user.id
    } as $authToken
  }

  response = {authToken: $authToken}
  guid = "WhWlwpC2CqOI1AM5ntQxgaGVWfM"
}