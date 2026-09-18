// Edit Gerados record
query "gerados/{gerados_id}" verb=PATCH {
  api_group = "Default"

  input {
    int gerados_id? filters=min:1
    dblink {
      table = "Gerados"
    }
  }

  stack {
    db.edit Gerados {
      field_name = "id"
      field_value = $input.gerados_id
      enforce_hidden_fields = false
      data = {}
    } as $gerados
  }

  response = $gerados
  guid = "xnO88RDsIpO4dTUZmG29E5LvWfY"
}