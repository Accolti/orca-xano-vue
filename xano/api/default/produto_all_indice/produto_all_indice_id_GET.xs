// Get produto_all_indice record
query "produto_all_indice/{produto_all_indice_id}" verb=GET {
  api_group = "Default"

  input {
    int produto_all_indice_id? filters=min:1
  }

  stack {
    db.get "" {
      field_name = "id"
      field_value = $input.produto_all_indice_id
    } as $produto_all_indice
  
    precondition ($produto_all_indice != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $produto_all_indice
  guid = "M90jZGrUPlyyzQRJpEnuApGiSlE"
}