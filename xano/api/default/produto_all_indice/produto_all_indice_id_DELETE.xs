// Delete produto_all_indice record.
query "produto_all_indice/{produto_all_indice_id}" verb=DELETE {
  api_group = "Default"

  input {
    int produto_all_indice_id? filters=min:1
  }

  stack {
    db.del "" {
      field_name = "id"
      field_value = $input.produto_all_indice_id
    }
  }

  response = null
  guid = "CKFU4EptXiKKeK2jRH73E4M08EU"
}