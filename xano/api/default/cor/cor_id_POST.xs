// Edit Cor record
query "cor/{cor_id}" verb=POST {
  api_group = "Default"

  input {
    int cor_id? filters=min:1
    dblink {
      table = "Cor"
    }
  }

  stack {
    db.edit Cor {
      field_name = "id"
      field_value = $input.cor_id
      enforce_hidden_fields = false
      data = {}
    } as $cor
  }

  response = $cor
  guid = "p32IaOjAf5HO49wTsVZQASNSWVY"
}