// Add Regra_Fiscal record
query regra_fiscal verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Regra_Fiscal"
    }
  }

  stack {
    db.add Regra_Fiscal {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $regra_fiscal
  }

  response = $regra_fiscal
  guid = "oA7URXB9UqJZPVMNN0OzsV8qVIo"
}