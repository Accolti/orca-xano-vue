// Query all preco_produto records
query preco_produto verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query preco_produto {
      return = {type: "list"}
    } as $preco_produto
  }

  response = $preco_produto
  guid = "mgYgIfNF-zCZ_nMn0mw3_JRm0uE"
}