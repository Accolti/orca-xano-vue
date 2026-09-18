// Get Organizacao record
query "organizacao/{organizacao_id}" verb=GET {
  api_group = "Default"

  input {
    int organizacao_id? filters=min:1
  }

  stack {
    db.get Organizacao {
      field_name = "id"
      field_value = $input.organizacao_id
    } as $organizacao
  
    precondition ($organizacao != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $organizacao
  guid = "Qg5i5DLiETnysnmubyyBDGLfrZs"
}