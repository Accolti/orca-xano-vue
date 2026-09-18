// Add Cor record
query cor verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Cor"
    }
  }

  stack {
    db.add Cor {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $cor
  }

  response = $cor
  guid = "-Az3IBFoZcgdVy4mZ4ZekQLSSrE"
}