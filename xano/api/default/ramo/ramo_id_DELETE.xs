// Delete Ramo record.
query "ramo/{ramo_id}" verb=DELETE {
  api_group = "Default"

  input {
    int ramo_id? filters=min:1
  }

  stack {
    db.del Ramo {
      field_name = "id"
      field_value = $input.ramo_id
    }
  }

  response = null
  guid = "bPChE8YQFyjQYPxfb0E335ENuVM"
}