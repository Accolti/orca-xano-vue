// Add Items record
query items verb=POST {
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
    } as $items
  }

  response = $items
  guid = "yOQT2ippGq19qoUwt6_cyuqH0jk"
}