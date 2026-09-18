// Add TestWithDate record
query testwithdate verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "TestWithDate"
    }
  }

  stack {
    db.add TestWithDate {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $testwithdate
  }

  response = $testwithdate
  guid = "ERShQwy8fd75CiH0iGlGlXRLK-w"
}