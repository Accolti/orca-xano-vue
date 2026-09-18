// Add Variacao record
query variacao verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Variacao"
    }
  }

  stack {
    db.add Variacao {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $variacao
  }

  response = $variacao
  guid = "bY3U5ytaZosLazq6dqIXJpAhEug"
}