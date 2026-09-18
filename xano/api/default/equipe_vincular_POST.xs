// Vincula uma conta existente como vendedor do admin (pai). Só admin/admin_geral.
// Não permite vincular a si mesmo nem o admin_geral; alvo não pode já ter pai.
query equipe_vincular verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    email email?
    decimal percentual_comissao?
  
    // "vendedor" (padrão) | "vendedor_master"
    text role? filters=trim
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
  
    precondition ($me.role == "admin" || $me.role == "admin_geral") {
      error_type = "accessdenied"
      error = "Apenas administradores podem vincular vendedores."
    }
  
    // Serviço de comissões (plano). admin_geral (sistema) sempre passa.
    function.run f_tem_comissoes {
      input = {user_id: $auth.id}
    } as $temComissoes
  
    precondition (($me.role == "admin_geral") || ($temComissoes)) {
      error_type = "accessdenied"
      error = "Sem acesso a esta funcionalidade."
    }
  
    db.get User {
      field_name = "email"
      field_value = $input.email
      output = ["id", "email", "role", "vendedor_pai_id"]
    } as $alvo
  
    precondition ($alvo != null) {
      error_type = "badrequest"
      error = "Usuário com esse e-mail não encontrado."
    }
  
    precondition ($alvo.id != $auth.id) {
      error_type = "badrequest"
      error = "Você não pode se vincular a si mesmo."
    }
  
    precondition ($alvo.role != "admin_geral") {
      error_type = "badrequest"
      error = "Não é possível vincular o administrador geral."
    }
  
    precondition (($alvo.vendedor_pai_id == null) || ($alvo.vendedor_pai_id == 0)) {
      error_type = "badrequest"
      error = "Este usuário já pertence a outra equipe."
    }
  
    var $novo_role {
      value = "vendedor"
    }
  
    conditional {
      if ($input.role == "vendedor_master") {
        precondition (($me.role == "admin") || ($me.role == "admin_geral")) {
          error_type = "accessdenied"
          error = "Apenas administradores podem vincular um Vendedor Master."
        }
      
        var.update $novo_role {
          value = "vendedor_master"
        }
      }
    }
  
    db.edit User {
      field_name = "id"
      field_value = $alvo.id
      enforce_hidden_fields = false
      data = {
        role               : $novo_role
        vendedor_pai_id    : $auth.id
        percentual_comissao: $input.percentual_comissao
      }
    } as $editado
  }

  response = {
    id                 : $editado.id
    email              : $editado.email
    role               : $editado.role
    vendedor_pai_id    : $editado.vendedor_pai_id
    percentual_comissao: $editado.percentual_comissao
  }

  tags = ["equipe", "f3"]
  guid = "equipe-vincular-f3-0001"
}