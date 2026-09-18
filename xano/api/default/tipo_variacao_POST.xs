// Add Tipo_Variacao record
query tipo_variacao verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Tipo_Variacao"
    }
  }

  stack {
    db.add Tipo_Variacao {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $tipo_variacao
  }

  response = $tipo_variacao
  guid = "v289Tagzu5jvpQYrvmapuY5egyw"
}