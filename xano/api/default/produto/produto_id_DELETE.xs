// Delete produto record.
query "produto/{produto_id}" verb=DELETE {
  api_group = "Default"

  input {
    int produto_id? filters=min:1
  }

  stack {
    db.del Produto {
      field_name = "id"
      field_value = $input.produto_id
    }
  }

  response = null
  guid = "207enM7d0dA5EDrGYSibmOIScls"
}