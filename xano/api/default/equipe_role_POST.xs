// Define o papel de um usuário (somente admin_geral). Promoção a "admin" limpa o
// vendedor_pai_id. Não altera o próprio usuário nem cria admin_geral.
query equipe_role verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int user_id? {
      table = "User"
    }
  
    text role? filters=trim
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role"]
    } as $me
  
    precondition ($me.role == "admin_geral") {
      error_type = "accessdenied"
      error = "Apenas o administrador geral altera papéis."
    }
  
    precondition ($input.user_id != $auth.id) {
      error_type = "badrequest"
      error = "Você não pode alterar o próprio papel."
    }
  
    precondition ($input.role == "admin" || $input.role == "vendedor" || $input.role == "vendedor_master") {
      error_type = "badrequest"
      error = "Papel inválido."
    }
  
    db.get User {
      field_name = "id"
      field_value = $input.user_id
      output = ["id", "role", "vendedor_pai_id"]
    } as $alvo
  
    precondition ($alvo != null) {
      error_type = "notfound"
      error = "Usuário não encontrado."
    }
  
    // Promover a admin → conta independente (limpa vínculo). Manter vendedor/master exige
    // pertencer a um admin; sem pai definido o vínculo é mantido do jeito que está.
    var $novo_pai {
      value = $alvo.vendedor_pai_id
    }
  
    conditional {
      if ($input.role == "admin") {
        var.update $novo_pai {
          value = null
        }
      }
    }
  
    db.edit User {
      field_name = "id"
      field_value = $input.user_id
      enforce_hidden_fields = false
      data = {role: $input.role, vendedor_pai_id: $novo_pai}
    } as $editado
  }

  response = {
    id             : $editado.id
    email          : $editado.email
    role           : $editado.role
    vendedor_pai_id: $editado.vendedor_pai_id
  }

  tags = ["equipe", "f3"]
  guid = "equipe-role-f3-0001"
}