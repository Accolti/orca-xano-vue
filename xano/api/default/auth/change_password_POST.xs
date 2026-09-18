// Troca de senha do usuário logado (auth User).
// Valida a senha atual via security.check_password e grava a nova (o Xano hasheia
// o campo do tipo senha no db.edit, igual ao signup).
query "auth/change_password" verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    text current_password?
    text new_password?
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "password"]
    } as $user
  
    security.check_password {
      text_password = $input.current_password
      hash_password = $user.password
    } as $pass_result
  
    precondition ($pass_result) {
      error_type = "badrequest"
      error = "Senha atual incorreta."
    }
  
    db.edit User {
      field_name = "id"
      field_value = $auth.id
      enforce_hidden_fields = false
      data = {password: $input.new_password}
    } as $user_editado
  }

  response = {ok: true}
  guid = "auth-change-password-custom-0001"
}