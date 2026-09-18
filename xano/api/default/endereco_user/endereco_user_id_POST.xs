// Edit endereco_user record
query "endereco_user/{endereco_user_id}" verb=POST {
  api_group = "Default"

  input {
    int endereco_user_id? filters=min:1
    dblink {
      table = ""
    }
  }

  stack {
    db.edit "" {
      field_name = "id"
      field_value = $input.endereco_user_id
      enforce_hidden_fields = false
      data = {}
    } as $endereco_user
  }

  response = $endereco_user
  guid = "_PbxYCL58goY2rrG3AKhGbeJIgg"
}