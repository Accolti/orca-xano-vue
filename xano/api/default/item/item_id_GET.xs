// Get item record
query "item/{item_id}" verb=GET {
  api_group = "Default"

  input {
    int item_id? filters=min:1
  }

  stack {
    db.get item {
      field_name = "id"
      field_value = $input.item_id
    } as $item
  
    precondition ($item != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $item
  guid = "SNecYxu5PU9knFkmMV9MaqA-gGU"
}