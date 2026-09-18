// Delete preco_produto record.
query "preco_produto/{preco_produto_id}" verb=DELETE {
  api_group = "Default"

  input {
    int preco_produto_id? filters=min:1
  }

  stack {
    db.del preco_produto {
      field_name = "id"
      field_value = $input.preco_produto_id
    }
  }

  response = null
  guid = "6Rk0_G7fLqy0wSslS8SsHwOPl88"
}