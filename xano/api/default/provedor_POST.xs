// Add Provedor record
query provedor verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Provedor"
    }
  }

  stack {
    db.add Provedor {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $provedor
  }

  response = $provedor
  guid = "hS8vnk4XcgTfIg94FgwxMfNp7Tw"
}