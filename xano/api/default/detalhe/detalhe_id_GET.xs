// Get Detalhe record
query "detalhe/{detalhe_id}" verb=GET {
  api_group = "Default"

  input {
    int detalhe_id? filters=min:1
  }

  stack {
    db.get Detalhe {
      field_name = "id"
      field_value = $input.detalhe_id
    } as $detalhe
  
    precondition ($detalhe != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $detalhe
  guid = "8gMjFtb0u7AWJV16eR8Ix1uuB-M"
}