// Edit Transportadora record
query "transportadora/{transportadora_id}" verb=PATCH {
  api_group = "Default"

  input {
    int transportadora_id? filters=min:1
    dblink {
      table = ""
    }
  }

  stack {
    db.edit "" {
      field_name = "id"
      field_value = $input.transportadora_id
      enforce_hidden_fields = false
      data = {}
    } as $transportadora
  }

  response = $transportadora
  guid = "IcsukV-6qu7A0xuczaM6j1usEpc"
}