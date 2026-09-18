// Delete telefone_user record.
query "telefone_user/{telefone_user_id}" verb=DELETE {
  api_group = "Default"

  input {
    int telefone_user_id? filters=min:1
  }

  stack {
    db.del telefone_user {
      field_name = "id"
      field_value = $input.telefone_user_id
    }
  }

  response = null
  guid = "8gcOR6895OqiXAddXe45kHkTGtA"
}