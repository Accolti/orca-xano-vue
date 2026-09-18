// Query all classificacao records
query classificacao verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Classificacao {
      return = {type: "list"}
    } as $classificacao
  }

  response = $classificacao
  guid = "2qlVlqIJaL6A_piHlYy37GrodzU"
}