// Query all Ramo records
query ramo verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Ramo {
      return = {type: "list"}
    } as $ramo
  }

  response = $ramo
  guid = "z1be5OsH7lCqN47BcVq18luKmrY"
}