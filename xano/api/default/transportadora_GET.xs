// Query all Transportadora records
query transportadora verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query "" {
      return = {type: "list"}
    } as $transportadora
  }

  response = $transportadora
  guid = "36Q_cjTcRTYrRCUM1z1HSb4ZG78"
}