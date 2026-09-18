// Delete_Orcamento
query orcamento_deletar verb=DELETE {
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
  
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
      output = ["id", "user_id", "eh_pedido"]
    } as $OrcaDel
  
    precondition (($OrcaDel != null) && ($OrcaDel.user_id == $auth.id)) {
      error_type = "unauthorized"
      error = "Você não pode excluir esse orçamento"
    }
  
    // Só enquanto é orçamento — depois que vira pedido, não pode excluir
    precondition ($OrcaDel.eh_pedido != true) {
      error_type = "badrequest"
      error = "Orçamento convertido em pedido não pode ser excluído."
    }
  
    function.run "Orcamento/f_excluir_orcamento" {
      input = {orca_id: $input.orca_id}
    } as $func1
  }

  response = $func1
  tags = ["orcamento"]
  guid = "OwnW6jsv0iTfirDgcHfWtvbRHU8"
}