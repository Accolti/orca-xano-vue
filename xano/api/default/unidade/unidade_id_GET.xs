// Get Unidade record
query "unidade/{unidade_id}" verb=GET {
  api_group = "Default"

  input {
    int unidade_id? filters=min:1
  }

  stack {
    db.get Unidade {
      field_name = "id"
      field_value = $input.unidade_id
    } as $unidade
  
    precondition ($unidade != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $unidade
  guid = "TcqBHgZzdDVlgY1lrsJtfgIrCJs"
}