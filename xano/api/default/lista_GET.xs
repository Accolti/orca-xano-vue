// Query all Lista records
query lista verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query "" {
      return = {type: "list"}
    } as $lista
  }

  response = $lista
  guid = "vf9KjEVN4SBRKFZLlSdJDP5GHnI"
}