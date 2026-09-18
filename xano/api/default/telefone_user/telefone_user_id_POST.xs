// Edit telefone_user record
query "telefone_user/{telefone_user_id}" verb=POST {
  api_group = "Default"

  input {
    int telefone_user_id? filters=min:1
    dblink {
      table = "telefone_user"
    }
  }

  stack {
    db.edit telefone_user {
      field_name = "id"
      field_value = $input.telefone_user_id
      enforce_hidden_fields = false
      data = {}
    } as $telefone_user
  }

  response = $telefone_user
  guid = "Zj9LKR2wCGobQ7btS_dq8WTE_Ls"
}