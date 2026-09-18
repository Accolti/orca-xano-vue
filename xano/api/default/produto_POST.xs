// Add produto record
query produto verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Produto"
    }
  }

  stack {
    db.add Produto {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $produto
  }

  response = $produto
  guid = "B5CT8J58bpQnH5hLh-UzsN8gAQc"
}