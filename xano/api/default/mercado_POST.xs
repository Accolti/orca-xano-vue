// Add Mercado record
query mercado verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Mercado"
    }
  }

  stack {
    db.add Mercado {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $mercado
  }

  response = $mercado
  guid = "5v2nLn6B9vVMT3IbMc2_9MuioJA"
}