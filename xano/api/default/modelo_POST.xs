// Add Modelo record
query modelo verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Modelo"
    }
  }

  stack {
    db.add Modelo {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $modelo
  }

  response = $modelo
  guid = "-qBfRC-CdK5fb2yxiY6i724Hz6M"
}