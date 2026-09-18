// Add Transportadora record
query transportadora verb=POST {
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
    } as $transportadora
  }

  response = $transportadora
  guid = "nYt4LWH-dkR5nrryzcm5ozKYcSk"
}