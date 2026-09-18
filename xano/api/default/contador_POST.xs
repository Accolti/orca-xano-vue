// Add Contador record
query contador verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Contador"
    }
  }

  stack {
    db.add Contador {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $contador
  }

  response = $contador
  guid = "SDxFrwBej1Fly8hp1DgBlvY4BYk"
}