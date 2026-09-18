// Add produto_all_indice record
query produto_all_indice verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = ""
    }
  }

  stack {
    db.add "" {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $produto_all_indice
  }

  response = $produto_all_indice
  guid = "YrTCRGYdonApQyThBSlT8hxRBVo"
}