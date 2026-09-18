// Query all Contador records
query contador verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Contador {
      return = {type: "list"}
    } as $contador
  }

  response = $contador
  guid = "-IkQzhXH6Uw6h1tQ3y4w7raZIuw"
}