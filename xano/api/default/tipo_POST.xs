// Add tipo record
query tipo verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Tipo"
    }
  }

  stack {
    db.add Tipo {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $tipo
  }

  response = $tipo
  guid = "0_znGjFTTmVnLAnnEswccWCFWws"
}