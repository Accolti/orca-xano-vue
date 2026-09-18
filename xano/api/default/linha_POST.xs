// Add linha record
query linha verb=POST {
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
    } as $linha
  }

  response = $linha
  guid = "MnTpzqgJFH7TMwirSn44JsgawE0"
}