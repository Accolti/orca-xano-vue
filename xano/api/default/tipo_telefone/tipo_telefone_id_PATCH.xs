// Edit Tipo_Telefone record
query "tipo_telefone/{tipo_telefone_id}" verb=PATCH {
  api_group = "Default"

  input {
    int tipo_telefone_id? filters=min:1
    dblink {
      table = "Tipo_Telefone"
    }
  }

  stack {
    db.edit Tipo_Telefone {
      field_name = "id"
      field_value = $input.tipo_telefone_id
      enforce_hidden_fields = false
      data = {}
    } as $tipo_telefone
  }

  response = $tipo_telefone
  guid = "Tafk6qGqFbWIxnz4RPNbaJF9d4A"
}