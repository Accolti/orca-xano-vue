// Add Ramo record
query ramo verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Ramo"
    }
  }

  stack {
    db.add Ramo {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $ramo
  }

  response = $ramo
  guid = "dveiew6xPplYuUYeTmCR6fQVcRA"
}