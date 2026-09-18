// Edit Items record
query "items/{items_id}" verb=POST {
  api_group = "Default"

  input {
    int items_id? filters=min:1
    dblink {
      table = ""
    }
  }

  stack {
    db.edit "" {
      field_name = "id"
      field_value = $input.items_id
      enforce_hidden_fields = false
      data = {}
    } as $items
  }

  response = $items
  guid = "vlWH-yWnIRFbQKmmAJA1_l95-gk"
}