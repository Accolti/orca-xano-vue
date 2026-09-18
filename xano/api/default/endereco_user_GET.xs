// Query all endereco_user records
query endereco_user verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query "" {
      return = {type: "list"}
    } as $endereco_user
  }

  response = $endereco_user
  guid = "AcZinHTkzzLV2XugW6e1yQd2oY0"
}