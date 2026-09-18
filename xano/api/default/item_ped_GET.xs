query item_ped verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query item_ped {
      return = {type: "list"}
    } as $model
  }

  response = $model
  guid = "7tLAro2eV10orFo4iYOd2ION6VU"
}