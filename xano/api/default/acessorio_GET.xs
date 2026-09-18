// Query all acessorio records
query acessorio verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Acessorio {
      return = {type: "list"}
    } as $acessorio
  }

  response = $acessorio
  guid = "8A81OspRg2JiN6nQdJzY7OMl2NU"
}