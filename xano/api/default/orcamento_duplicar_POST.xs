// Duplica um orçamento com nova numeração
query Orcamento_Duplicar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    int user_id? {
      table = "User"
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
  
    function.run "Orcamento/f_DuplicaOrcamento" {
      input = {orca_id: $input.orca_id, user_id: $input.user_id}
    } as $func1
  }

  response = $func1
  tags = ["orcamento"]
  guid = "oSrPZvXO-iOCEtWFmM4f12x6h_s"
}