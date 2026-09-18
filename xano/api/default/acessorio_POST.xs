// Add acessorio record
query acessorio verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Acessorio"
    }
  }

  stack {
    db.add Acessorio {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $acessorio
  }

  response = $acessorio
  guid = "WhwxgLMERXwFgsSlX1sDVRySHPA"
}