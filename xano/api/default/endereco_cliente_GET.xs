// Query all endereco_cliente records
query endereco_cliente verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Endereco_Cliente {
      return = {type: "list"}
    } as $endereco_cliente
  }

  response = $endereco_cliente
  guid = "olhTajS-PfR1vp2mQlnMZ0EoJXQ"
}