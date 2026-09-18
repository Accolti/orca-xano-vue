// Edit produto record
query "produto/{produto_id}" verb=POST {
  api_group = "Default"

  input {
    int produto_id? filters=min:1
    dblink {
      table = "Produto"
    }
  }

  stack {
    db.edit Produto {
      field_name = "id"
      field_value = $input.produto_id
      enforce_hidden_fields = false
      data = {}
    } as $produto
  }

  response = $produto
  guid = "cl9WH6UDEjgMZFLolVcdaQvSgxI"
}