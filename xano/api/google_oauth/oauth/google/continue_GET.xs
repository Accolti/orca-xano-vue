// This endpoint handles both login and signup depending on the state of the user account.
query "oauth/google/continue" verb=GET {
  api_group = "google-oauth"

  input {
    text code? filters=trim
    text redirect_uri? filters=trim
  }

  stack {
    function.run google_oauth_getaccesstoken {
      input = {code: $input.code, redirect_uri: $input.redirect_uri}
    } as $token
  
    function.run google_oauth_getuserinfo {
      input = {token: $token}
    } as $userinfo
  
    // Busca o usuário pelo e-mail (mais robusto que google_oauth.id).
    // O e-mail do Google é o mesmo do cadastro, então vincula automaticamente.
    db.get User {
      field_name = "email"
      field_value = $userinfo.email
    } as $user
  
    precondition ($user != null) {
      error_type = "accessdenied"
      error = "Usuário não cadastrado. Entre em contato com o suporte."
    }
  
    // Usuário (ou um "pai" na hierarquia) desativado não pode entrar
    function.run f_ativo_efetivo {
      input = {user_id: $user.id}
    } as $ativoEfetivo
  
    precondition ($ativoEfetivo) {
      error_type = "accessdenied"
      error = "Conta inativa. Fale com o administrador."
    }
  
    // Auto-vincula o google_oauth no primeiro login via Google
    conditional {
      if (!$user.google_oauth.id) {
        db.edit User {
          field_name = "id"
          field_value = $user.id
          enforce_hidden_fields = false
          data = {
            google_oauth: {
            id   : $userinfo.id
            name : $userinfo.name
            email: $userinfo.email
          }
          }
        } as $user_atualizado
      }
    }
  
    security.create_auth_token {
      table = "User"
      extras = {}
      expiration = 86400
      id = $user.id
    } as $token
  }

  response = {
    token: $token
    name : $userinfo.name
    email: $userinfo.email
  }

  guid = "JbR106dB9mKnEPYy-Z_yObf4jjM."
}