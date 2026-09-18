// Exclui uma taxa de cartão da empresa. Admin da empresa; admin_geral qualquer.
query taxa_banco_excluir verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int id? {
      table = "Taxa_Banco"
    }
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
      error = "Apenas administradores gerenciam as taxas."
    }
  
    db.get Taxa_Banco {
      field_name = "id"
      field_value = $input.id
    } as $existente
  
    precondition ($existente != null) {
      error_type = "notfound"
      error = "Taxa não encontrada."
    }
  
    function.run f_empresa_id {
      input = {user_id: $auth.id}
    } as $empresa_id
  
    precondition (($me.role == "admin_geral") || ($existente.user_id == $empresa_id)) {
      error_type = "accessdenied"
      error = "Você não pode excluir esta taxa."
    }
  
    db.del Taxa_Banco {
      field_name = "id"
      field_value = $input.id
    }
  }

  response = null
  tags = ["novo-sis", "taxas"]
  guid = "taxa-banco-excluir-0001"
}
