// Query all Organizacao records
query organizacao verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Organizacao {
      return = {type: "list"}
    } as $organizacao
  }

  response = $organizacao
  guid = "unlpnrw1cFuTgUL-Qbk6zKiN9Fw"
}