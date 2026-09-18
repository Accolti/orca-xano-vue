// Add telefone_user record
query telefone_user verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "telefone_user"
    }
  }

  stack {
    db.add telefone_user {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $telefone_user
  }

  response = $telefone_user
  guid = "7eKPjOFRMZm_BgM9J24CTyK0TXk"
}