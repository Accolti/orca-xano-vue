// Edit telefone_cliente record
query "telefone_cliente/{telefone_cliente_id}" verb=POST {
  api_group = "Default"

  input {
    int telefone_cliente_id? filters=min:1
    dblink {
      table = "Telefone_Cliente"
    }
  }

  stack {
    db.edit Telefone_Cliente {
      field_name = "id"
      field_value = $input.telefone_cliente_id
      enforce_hidden_fields = false
      data = {}
    } as $telefone_cliente
  }

  response = $telefone_cliente
  guid = "QimiJRjYOvGU5JwWugDiPeN2a5U"
}