// Add Unidade record
query unidade verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Unidade"
    }
  }

  stack {
    db.add Unidade {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $unidade
  }

  response = $unidade
  guid = "XJdL98LgtALQKKvggQcF7A9PhRk"
}