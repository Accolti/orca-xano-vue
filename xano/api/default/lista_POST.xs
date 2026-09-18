// Add Lista record
query lista verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = ""
    }
  }

  stack {
    db.add "" {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $lista
  }

  response = $lista
  guid = "iSM9d1dkXHYRqR3PXVvi92cOS28"
}