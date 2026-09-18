// novo-sis: exclui uma parcela financeira (boleto/Pix/cartão).
query pagamento_excluir verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int boleto_id? {
      table = "Boleto"
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
  
    db.get Boleto {
      field_name = "id"
      field_value = $input.boleto_id
    } as $Boleto_0
  
    precondition ($Boleto_0 != null) {
      error_type = "notfound"
      error = "Parcela não encontrada."
    }
  
    precondition ($Boleto_0.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "Acesso negado."
    }
  
    db.del Boleto {
      field_name = "id"
      field_value = $input.boleto_id
    }
  }

  response = {ok: true}
  tags = ["pagamento", "novo-sis"]
  guid = "pagamento-excluir-novo-sis-0001"
}