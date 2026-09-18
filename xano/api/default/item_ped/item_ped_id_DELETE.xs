query "item_ped/{item_ped_id}" verb=DELETE {
  api_group = "Default"

  input {
    int item_ped_id? filters=min:1
  }

  stack {
    db.del item_ped {
      field_name = "id"
      field_value = $input.item_ped_id
    }
  }

  response = null
  guid = "L-AjijVP7blYPXqGcwz27_SaZCg"
}