// Add Configuracoes record
query configuracoes verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Configuracoes"
    }
  }

  stack {
    db.add Configuracoes {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $configuracoes
  }

  response = $configuracoes
  guid = "7KsBnKTouEMDY8m2ZpJ0sXselSU"
}