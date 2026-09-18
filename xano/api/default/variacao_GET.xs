// Query all Variacao records
query variacao verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Variacao {
      return = {type: "list"}
    } as $variacao
  }

  response = $variacao
  guid = "gmJ1DXm39kYWZHTDqQAbNFrSOSI"
}