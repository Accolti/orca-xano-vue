// Delete TestWithDate record.
query "testwithdate/{testwithdate_id}" verb=DELETE {
  api_group = "Default"

  input {
    int testwithdate_id? filters=min:1
  }

  stack {
    db.del TestWithDate {
      field_name = "id"
      field_value = $input.testwithdate_id
    }
  }

  response = null
  guid = "5PDQ2M0PrDwDfrHhMMxy0-vuQp0"
}