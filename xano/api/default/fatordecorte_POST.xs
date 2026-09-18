// Add fatordecorte record
query fatordecorte verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Fator_de_Corte"
    }
  }

  stack {
    db.add Fator_de_Corte {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $fatordecorte
  }

  response = $fatordecorte
  guid = "AXelmDYuG6wpr86772NUwhAZHAE"
}