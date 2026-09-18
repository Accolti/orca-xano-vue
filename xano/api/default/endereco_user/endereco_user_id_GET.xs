// Get endereco_user record
query "endereco_user/{endereco_user_id}" verb=GET {
  api_group = "Default"

  input {
    int endereco_user_id? filters=min:1
  }

  stack {
    db.get "" {
      field_name = "id"
      field_value = $input.endereco_user_id
    } as $endereco_user
  
    precondition ($endereco_user != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $endereco_user
  guid = "0HYZzAefyDeVR-EGBbu_PMDhW9M"
}