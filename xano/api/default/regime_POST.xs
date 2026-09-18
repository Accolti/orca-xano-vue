// Add Regime record
query regime verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Regime"
    }
  }

  stack {
    db.add Regime {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $regime
  }

  response = $regime
  guid = "0yyqrPrhSd0nY6k4nIgEoOehGW0"
}