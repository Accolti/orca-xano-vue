// Query all user records
query user verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query User {
      join = {
        Regime: {
          table: "Regime"
          type : "left"
          where: $db.User.regime_id == $db.Regime.id
        }
      }
    
      eval = {regime: $db.Regime.descricao}
      return = {type: "list"}
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
        "razao"
        "fantasia"
        "cnpj"
        "ie"
        "cpf"
        "isPJ"
        "regime_id"
        "regime"
        "logo.access"
        "logo.path"
        "logo.name"
        "logo.type"
        "logo.size"
        "logo.mime"
        "logo.meta"
        "logo.url"
        "google_oauth.id"
        "google_oauth.name"
        "google_oauth.email"
      ]
    } as $user
  }

  response = $user
  guid = "iNOYoBGwByKuuGLGVR9vGgyBOj8"
}