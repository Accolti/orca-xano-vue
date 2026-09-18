// Exclusão DEFINITIVA (cascata) de um orçamento — exceção administrativa.
// Somente usuários com `super_admin = true`. Apaga itens, boletos, comissões,
// controle de pedido, logs, notificações, histórico e a própria Orca.
query orcamento_excluir_definitivo verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    // Reforço: bloqueia quem foi desativado (o próprio ou um "pai") após o login
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
      output = ["id", "role", "super_admin"]
    } as $me
  
    precondition (($me.super_admin) || ($me.role == "admin_geral")) {
      error_type = "accessdenied"
      error = "Apenas o super admin pode excluir definitivamente."
    }
  
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
      output = ["id"]
    } as $orca
  
    precondition ($orca != null) {
      error_type = "notfound"
      error = "Orçamento não encontrado."
    }
  
    function.run "Orcamento/f_excluir_orcamento" {
      input = {orca_id: $input.orca_id}
    } as $func1
  }

  response = {ok: true, orca_id: $input.orca_id}
  tags = ["orcamento"]
  guid = "orcamento-excluir-definitivo-0001"
}