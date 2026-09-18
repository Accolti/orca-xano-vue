// Delete Lista record.
query "lista/{lista_id}" verb=DELETE {
  api_group = "Default"

  input {
    int lista_id? filters=min:1
  }

  stack {
    db.del "" {
      field_name = "id"
      field_value = $input.lista_id
    }
  }

  response = null
  guid = "cXefLdXpHkykRHZHPxShZ0jv6I4"
}