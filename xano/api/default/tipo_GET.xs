// Query all tipo records
query tipo verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Tipo {
      return = {type: "list"}
    } as $tipo
  }

  response = $tipo
  guid = "x3rAqIdxbj45HjsamU83bVyzTa4"
}