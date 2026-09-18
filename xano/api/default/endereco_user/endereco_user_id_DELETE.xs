// Delete endereco_user record.
query "endereco_user/{endereco_user_id}" verb=DELETE {
  api_group = "Default"

  input {
    int endereco_user_id? filters=min:1
  }

  stack {
    db.del "" {
      field_name = "id"
      field_value = $input.endereco_user_id
    }
  }

  response = null
  guid = "N_RXRnrb3hA-5sNsU5b_wsPZfCM"
}