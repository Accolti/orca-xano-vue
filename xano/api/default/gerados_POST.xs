// Add Gerados record
query gerados verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Gerados"
    }
  }

  stack {
    db.add Gerados {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $gerados
  }

  response = $gerados
  guid = "VHf3gLRM0FNgCxFRkvPdyfYWw88"
}