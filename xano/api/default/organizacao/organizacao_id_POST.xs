// Edit Organizacao record
query "organizacao/{organizacao_id}" verb=POST {
  api_group = "Default"

  input {
    int organizacao_id? filters=min:1
    dblink {
      table = "Organizacao"
    }
  }

  stack {
    db.edit Organizacao {
      field_name = "id"
      field_value = $input.organizacao_id
      enforce_hidden_fields = false
      data = {}
    } as $organizacao
  }

  response = $organizacao
  guid = "bxYH9BJ_x7GQlbhTCkm2DzqwxRY"
}