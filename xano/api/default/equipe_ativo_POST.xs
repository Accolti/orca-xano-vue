// Liga/desliga um vendedor da equipe (dono/pai ou admin_geral). Só o campo `ativo`.
// Endpoint dedicado: no Xano, input opcional `bool` ausente vira `false` (não null),
// então um `db.edit` parcial no `equipe_editar` apagaria os demais campos.
query equipe_ativo verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int user_id? {
      table = "User"
    }
  
    bool ativo?
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
  
    db.edit User {
      field_name = "id"
      field_value = $input.user_id
      enforce_hidden_fields = false
      data = {ativo: $input.ativo}
    } as $editado
  }

  response = {id: $editado.id, ativo: $editado.ativo}
  tags = ["equipe", "f3"]
  guid = "equipe-ativo-f3-0001"
}