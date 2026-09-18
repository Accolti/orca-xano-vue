// Salva o cadastro de um vendedor da equipe (snapshot completo): comissão, ativo e
// limites de desconto. O front SEMPRE envia os 5 campos, evitando o problema de
// input opcional ausente (no Xano, `bool` ausente = false e `decimal` ausente = 0).
// Dono (pai) ou admin_geral.
query equipe_salvar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int user_id? {
      table = "User"
    }
  
    decimal percentual_comissao?
    bool ativo?
  
    // 0 = herda o padrão da empresa
    decimal desconto_livre_perc?
  
    decimal desconto_max_perc?
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
      output = ["id", "role"]
    } as $me
  
    db.get User {
      field_name = "id"
      field_value = $input.user_id
      output = ["id", "vendedor_pai_id", "role"]
    } as $alvo
  
    precondition ($alvo != null) {
      error_type = "notfound"
      error = "Vendedor não encontrado."
    }
  
    precondition (($me.role == "admin_geral") || ($alvo.vendedor_pai_id == $auth.id)) {
      error_type = "accessdenied"
      error = "Você não pode editar este vendedor."
    }
  
    // Serviço de comissões (plano). admin_geral (sistema) sempre passa.
    function.run f_tem_comissoes {
      input = {user_id: $auth.id}
    } as $temComissoes
  
    precondition (($me.role == "admin_geral") || ($temComissoes)) {
      error_type = "accessdenied"
      error = "Sem acesso a esta funcionalidade."
    }
  
    db.edit User {
      field_name = "id"
      field_value = $input.user_id
      enforce_hidden_fields = false
      data = {
        percentual_comissao: $input.percentual_comissao
        ativo              : $input.ativo
        desconto_livre_perc: $input.desconto_livre_perc
        desconto_max_perc  : $input.desconto_max_perc
      }
    } as $editado
  }

  response = {
    id                 : $editado.id
    email              : $editado.email
    role               : $editado.role
    percentual_comissao: $editado.percentual_comissao
    ativo              : $editado.ativo
    desconto_livre_perc: $editado.desconto_livre_perc
    desconto_max_perc  : $editado.desconto_max_perc
  }

  tags = ["equipe", "f3"]
  guid = "equipe-salvar-f3-0001"
}