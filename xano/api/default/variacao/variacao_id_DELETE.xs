// Delete Variacao record.
query "variacao/{variacao_id}" verb=DELETE {
  api_group = "Default"

  input {
    int variacao_id? filters=min:1
  }

  stack {
    db.del Variacao {
      field_name = "id"
      field_value = $input.variacao_id
    }
  }

  response = null
  guid = "_K8oxW1ZHbCYhBYf90YK-J7m4tY"
}