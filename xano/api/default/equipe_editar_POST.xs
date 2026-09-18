// Edita um vendedor da equipe (percentual/ativo). Dono (pai) ou admin_geral.
query equipe_editar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int user_id? {
      table = "User"
    }
  
    decimal percentual_comissao?
  
    // Override de desconto do vendedor (0 = herda o padrão da empresa)
    decimal desconto_livre_perc?
  
    decimal desconto_max_perc?
  }

  stack {
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
  
    // Edita comissão + limites de desconto (o `ativo` tem endpoint próprio:
    // `equipe_ativo`). Grava os 3 campos sempre — o front envia todos.
    db.edit User {
      field_name = "id"
      field_value = $input.user_id
      enforce_hidden_fields = false
      data = {
        percentual_comissao: $input.percentual_comissao
        desconto_livre_perc: $input.desconto_livre_perc
        desconto_max_perc  : $input.desconto_max_perc
      }
    } as $ed_desc
  
    db.get User {
      field_name = "id"
      field_value = $input.user_id
    } as $editado
  }

  response = {
    id                 : $editado.id
    email              : $editado.email
    role               : $editado.role
    percentual_comissao: $editado.percentual_comissao
    ativo              : $editado.ativo
  }

  tags = ["equipe", "f3"]
  guid = "equipe-editar-f3-0001"
}