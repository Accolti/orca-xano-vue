// Add endereco_cliente record
query endereco_cliente verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Endereco_Cliente"
    }
  }

  stack {
    db.add Endereco_Cliente {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $endereco_cliente
  }

  response = $endereco_cliente
  guid = "zDMSeHN1Z8kFSpmBfLSlgw17JcY"
}