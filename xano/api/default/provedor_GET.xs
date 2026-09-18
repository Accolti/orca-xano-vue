// Query all Provedor records
query provedor verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Provedor {
      return = {type: "list"}
    } as $provedor
  }

  response = $provedor
  guid = "KShLuGbKtbwB5sc-hxwl5RezBNE"
}