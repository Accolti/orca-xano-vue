// Get produto record
query "produto/{produto_id}" verb=GET {
  api_group = "Default"

  input {
    int produto_id? filters=min:1
  }

  stack {
    db.get Produto {
      field_name = "id"
      field_value = $input.produto_id
    } as $produto
  
    precondition ($produto != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $produto
  guid = "_uTsS-__U_Id7gRY9MCAnb_DU0g"
}