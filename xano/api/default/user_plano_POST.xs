// Define o plano (slug) de um usuário/empresa. Somente admin_geral (sistema).
// "plus" habilita o serviço de comissões; "basico" (ou ausente) não.
query user_plano verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int user_id? {
      table = "User"
    }
  
    text plano? filters=trim
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role"]
    } as $me
  
    precondition ($me.role == "admin_geral") {
      error_type = "accessdenied"
      error = "Apenas o administrador geral define planos."
    }
  
    precondition ($input.user_id != null) {
      error_type = "badrequest"
      error = "Informe o usuário."
    }
  
    precondition ($input.plano == "basico" || $input.plano == "plus") {
      error_type = "badrequest"
      error = "Plano inválido."
    }
  
    db.get User {
      field_name = "id"
      field_value = $input.user_id
      output = ["id"]
    } as $alvo
  
    precondition ($alvo != null) {
      error_type = "notfound"
      error = "Usuário não encontrado."
    }
  
    db.edit User {
      field_name = "id"
      field_value = $input.user_id
      enforce_hidden_fields = false
      data = {plano: $input.plano}
    } as $editado
  }

  response = {id: $editado.id, plano: $editado.plano}
  tags = ["plano", "f3"]
  guid = "user-plano-f3-0001"
}