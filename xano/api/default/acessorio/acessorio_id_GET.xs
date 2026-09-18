// Get acessorio record
query "acessorio/{acessorio_id}" verb=GET {
  api_group = "Default"

  input {
    int acessorio_id? filters=min:1
  }

  stack {
    db.get Acessorio {
      field_name = "id"
      field_value = $input.acessorio_id
    } as $acessorio
  
    precondition ($acessorio != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $acessorio
  guid = "nTQga4gkEO9XlMufAUTEH3dkbW4"
}