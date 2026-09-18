// Query all Modelo records
query modelo verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Modelo {
      return = {type: "list"}
    } as $modelo
  }

  response = $modelo
  guid = "QaMZGDyyHA3FXMjSYLmgevMVeyw"
}