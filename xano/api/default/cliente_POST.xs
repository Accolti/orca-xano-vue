// Add cliente record
query cliente verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Cliente"
    }
  }

  stack {
    db.add Cliente {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $cliente
  }

  response = $cliente
  guid = "csvBJqvguOZDX0J5P3wIHksI6wU"
}