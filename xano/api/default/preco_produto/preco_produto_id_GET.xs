// Get preco_produto record
query "preco_produto/{preco_produto_id}" verb=GET {
  api_group = "Default"

  input {
    int preco_produto_id? filters=min:1
  }

  stack {
    db.get preco_produto {
      field_name = "id"
      field_value = $input.preco_produto_id
    } as $preco_produto
  
    precondition ($preco_produto != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $preco_produto
  guid = "zhv_nxRpolnjfOFkEz3e94tk7eE"
}