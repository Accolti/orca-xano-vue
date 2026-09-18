// Get Items record
query "items/{items_id}" verb=GET {
  api_group = "Default"

  input {
    int items_id? filters=min:1
  }

  stack {
    db.get "" {
      field_name = "id"
      field_value = $input.items_id
    } as $items
  
    precondition ($items != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $items
  guid = "7v5PdN-qpmHDr6shccSTkEBl6AE"
}