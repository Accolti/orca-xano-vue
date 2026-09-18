// Edit user record
query "user/{user_id}" verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int user_id? filters=min:1 {
      visibility = "internal"
    }
  
    dblink {
      table = "User"
    }
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
    } as $user
  
    // UF do vendedor é obrigatória (usada como uf_destino na precificação)
    precondition (($input.uf != null) && ($input.uf != "")) {
      error_type = "badrequest"
      error = "UF é obrigatória."
    }
  
    db.edit User {
      field_name = "id"
      field_value = $auth.id
      enforce_hidden_fields = false
      data = {
        name                   : $input.name|first_notempty:$user.name
        name_first             : $input.name_first|first_notempty:$user.name_first
        name_last              : $input.name_last|first_notempty:$user.name_last
        email                  : $input.email|first_notempty:$user.email
        frtB2B                 : $input.frtB2B|first_notnull:$user.frtB2B
        margem                 : $input.margem|first_notnull:$user.margem
        DiasVencimentoOrcamento: $input.DiasVencimentoOrcamento|first_notempty:$user.DiasVencimentoOrcamento
        organizacao_id         : $input.organizacao_id|first_notempty:$user.organizacao_id
        razao                  : $input.razao|first_notempty:$user.razao
        fantasia               : $input.fantasia|first_notempty:$user.fantasia
        cnpj                   : $input.cnpj|first_notempty:$user.cnpj
        ie                     : $input.ie|first_notempty:$user.ie
        cpf                    : $input.cpf|first_notempty:$user.cpf
        isPJ                   : $input.isPJ|first_notempty:$user.isPJ
        uf                     : $input.uf|first_notempty:$user.uf
        regime_id              : $input.regime_id|first_notempty:$user.regime_id
        desconto_livre_perc    : $input.desconto_livre_perc|first_notnull:$user.desconto_livre_perc
        desconto_max_perc      : $input.desconto_max_perc|first_notnull:$user.desconto_max_perc
        logo                   : $input.logo|first_notempty:$user.logo
        google_oauth           : $input.google_oauth|first_notempty:$user.google_oauth
      }
    } as $user
  }

  response = $user
  guid = "aqidwFoMrhgFvihAQz2cXqz55l8"
}