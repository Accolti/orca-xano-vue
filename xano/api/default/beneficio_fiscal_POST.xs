// Add Beneficio_Fiscal record
query beneficio_fiscal verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Beneficio_Fiscal"
    }
  }

  stack {
    db.add Beneficio_Fiscal {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $beneficio_fiscal
  }

  response = $beneficio_fiscal
  guid = "qkh9A8SNDFqWK5rFWnKQWlZqYq4"
}