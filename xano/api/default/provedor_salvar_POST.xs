// Cria/edita um provedor (banco) de taxas. Admin da empresa; admin_geral qualquer.
// Campos de coleta automática (url_taxas/metodo/canal_default/seletor) preparados
// para o scraping futuro — ainda não coletados.
query provedor_salvar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int id? {
      table = "Provedor"
    }
  
    text nome? filters=trim
    text url_taxas? filters=trim
    text metodo? filters=trim
    text canal_default? filters=trim
    bool ativo?=true
  }

  stack {
    function.run f_ativo_efetivo {
      input = {user_id: $auth.id}
    } as $ativoEfetivo
  
    precondition ($ativoEfetivo) {
      error_type = "accessdenied"
      error = "Conta inativa. Fale com o administrador."
    }
  
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role", "vendedor_pai_id"]
    } as $me
  
    // Admin: role explícita OU legado sem role e sem pai (dono da conta)
    precondition ($me.role == "admin" || $me.role == "admin_geral" || (($me.role == null || $me.role == "") && ($me.vendedor_pai_id == null || $me.vendedor_pai_id == 0))) {
      error_type = "accessdenied"
      error = "Apenas administradores gerenciam provedores."
    }
  
    precondition (($input.nome != null) && ($input.nome != "")) {
      error_type = "badrequest"
      error = "Informe o nome do provedor."
    }
  
    conditional {
      if ($input.id != null) {
        db.edit Provedor {
          field_name = "id"
          field_value = $input.id
          enforce_hidden_fields = false
          data = {
            nome          : $input.nome
            url_taxas     : $input.url_taxas
            metodo        : $input.metodo|first_notnull:"manual"
            canal_default : $input.canal_default
            ativo         : $input.ativo
          }
        } as $salva
      }
    
      else {
        db.add Provedor {
          enforce_hidden_fields = false
          data = {
            nome          : $input.nome
            url_taxas     : $input.url_taxas
            metodo        : $input.metodo|first_notnull:"manual"
            canal_default : $input.canal_default
            ativo         : $input.ativo
            created_at    : "now"
          }
        } as $salva
      }
    }
  }

  response = $salva
  tags = ["novo-sis", "taxas"]
  guid = "provedor-salvar-0001"
}
