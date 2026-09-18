// Edit Ramo record
query "ramo/{ramo_id}" verb=POST {
  api_group = "Default"

  input {
    int ramo_id? filters=min:1
    dblink {
      table = "Ramo"
    }
  }

  stack {
    db.edit Ramo {
      field_name = "id"
      field_value = $input.ramo_id
      enforce_hidden_fields = false
      data = {}
    } as $ramo
  }

  response = $ramo
  guid = "bIiTSKRHOoUik7WO1ufZjpfPiNQ"
}