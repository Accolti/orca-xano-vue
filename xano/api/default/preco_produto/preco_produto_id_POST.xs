// Edit preco_produto record
query "preco_produto/{preco_produto_id}" verb=POST {
  api_group = "Default"

  input {
    int preco_produto_id? filters=min:1
    dblink {
      table = "preco_produto"
    }
  }

  stack {
    db.edit preco_produto {
      field_name = "id"
      field_value = $input.preco_produto_id
      enforce_hidden_fields = false
      data = {}
    } as $preco_produto
  }

  response = $preco_produto
  guid = "ox9njSxjlgD8GwezoLy-pSchTpE"
}