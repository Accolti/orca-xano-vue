// Add endereco_user record
query endereco_user verb=POST {
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
    } as $endereco_user
  }

  response = $endereco_user
  guid = "YJuI4_vZHmYy0fici9ach09bf5I"
}