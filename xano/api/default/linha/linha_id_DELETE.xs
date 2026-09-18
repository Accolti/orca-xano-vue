// Delete linha record.
query "linha/{linha_id}" verb=DELETE {
  api_group = "Default"

  input {
    int linha_id? filters=min:1
  }

  stack {
    db.del "" {
      field_name = "id"
      field_value = $input.linha_id
    }
  }

  response = null
  guid = "2YUa6rV7QQivp8nkg3sO6kXt7aA"
}