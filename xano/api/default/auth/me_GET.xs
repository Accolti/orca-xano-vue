// Get the user record belonging to the authentication token
query "auth/me" verb=GET {
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
        "razao"
        "fantasia"
        "cnpj"
        "ie"
        "cpf"
        "isPJ"
        "uf"
        "regime_id"
        "role"
        "vendedor_pai_id"
        "percentual_comissao"
        "ativo"
        "desconto_livre_perc"
        "desconto_max_perc"
        "plano"
        "super_admin"
        "logo"
      ]
    
      addon = [
        {
          name : "Telefone_User_of_User"
          input: {user_id: $auth.id}
          as   : "_telefones"
        }
        {
          name : "endereco_user_of_User"
          input: {user_id: $auth.id}
          as   : "_endereco_user"
        }
      ]
    } as $User
  
    // Ativo efetivo: considera o próprio e os ancestrais (pai inativo bloqueia)
    function.run f_ativo_efetivo {
      input = {user_id: $auth.id}
    } as $ativoEfetivo
  
    api.lambda {
      code = "return { user: Object.assign({}, $var.User || {}, { ativo_efetivo: $var.ativoEfetivo }) };"
      timeout = 5
    } as $res
  
    var $UserOut {
      value = $res.user
    }
  }

  response = $UserOut
  guid = "BKs1Wiey9ldwId7sbc2VwQcnegI"
}