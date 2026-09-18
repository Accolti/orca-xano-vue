// Add Organizacao record
query organizacao verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Organizacao"
    }
  }

  stack {
    db.add Organizacao {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $organizacao
  }

  response = $organizacao
  guid = "jjuncJdINSxPnVuU_XD-xj1k1bc"
}