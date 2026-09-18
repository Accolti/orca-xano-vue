// Add Detalhe record
query detalhe verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Detalhe"
    }
  }

  stack {
    db.add Detalhe {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $detalhe
  }

  response = $detalhe
  guid = "FTLnba-GQ3oUmstT_J4khNKFE9c"
}