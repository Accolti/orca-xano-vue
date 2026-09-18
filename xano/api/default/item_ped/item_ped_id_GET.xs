query "item_ped/{item_ped_id}" verb=GET {
  api_group = "Default"

  input {
    int item_ped_id? filters=min:1
  }

  stack {
    db.get item_ped {
      field_name = "id"
      field_value = $input.item_ped_id
    } as $model
  
    precondition ($model != null) {
      error_type = "notfound"
      error = "Not Found"
    }
  }

  response = $model
  guid = "7K9aoVjovj2_fHXunMcqi-1NOdY"
}