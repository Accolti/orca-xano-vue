// Add user record
query user verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "User"
    }
  }

  stack {
    db.add User {
      enforce_hidden_fields = false
      data = {
        created_at             : "now"
        name                   : $input.name
        name_first             : $input.name_first
        name_last              : $input.name_last
        email                  : $input.email
        frtB2B                 : $input.frtB2B
        margem                 : $input.margem
        DiasVencimentoOrcamento: $input.DiasVencimentoOrcamento
        organizacao_id         : $input.organizacao_id
        razao                  : $input.razao
        fantasia               : $input.fantasia
        cnpj                   : $input.cnpj
        ie                     : $input.ie
        cpf                    : $input.cpf
        isPJ                   : $input.isPJ
        regime_id              : $input.regime_id
        logo                   : $input.logo
        google_oauth           : $input.google_oauth
      }
    } as $user
  }

  response = $user
  guid = "q6y5h_A7oVBNrxIRFic4nOAUU9k"
}