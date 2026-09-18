// Delete Items record.
query "items/{items_id}" verb=DELETE {
  api_group = "Default"

  input {
    int items_id? filters=min:1
  }

  stack {
    !db.del "" {
      field_name = "id"
      field_value = $input.items_id
    }
  
    db.del item {
      field_name = "id"
      field_value = $input.items_id
    }
  }

  response = $item1
  guid = "ajtw_uIjZTzs2BqlTA5gbhOLLNw"
}