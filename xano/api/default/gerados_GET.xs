// Query all Gerados records
query gerados verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Gerados {
      return = {type: "list"}
    } as $gerados
  }

  response = $gerados
  guid = "xxKC0jVJLjijMZFxFmIpxBTvo3Q"
}