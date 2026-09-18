// Get linha record
query "linha/{linha_id}" verb=GET {
  api_group = "Default"

  input {
    int linha_id? filters=min:1
  }

  stack {
    db.get "" {
      field_name = "id"
      field_value = $input.linha_id
    } as $linha
  
    precondition ($linha != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $linha
  guid = "nzFUg6gKGT1pnsY2JJRsAMRYoJ8"
}