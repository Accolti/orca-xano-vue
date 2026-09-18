// Edit linha record
query "linha/{linha_id}" verb=POST {
  api_group = "Default"

  input {
    int linha_id? filters=min:1
    dblink {
      table = ""
    }
  }

  stack {
    db.edit "" {
      field_name = "id"
      field_value = $input.linha_id
      enforce_hidden_fields = false
      data = {}
    } as $linha
  }

  response = $linha
  guid = "aLdR4QH8ASyOaFeBqefWpyvL_Jo"
}