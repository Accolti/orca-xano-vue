// Edit endereco_cliente record
query "endereco_cliente/{endereco_cliente_id}" verb=POST {
  api_group = "Default"

  input {
    int endereco_cliente_id? filters=min:1
    dblink {
      table = "Endereco_Cliente"
    }
  }

  stack {
    db.edit Endereco_Cliente {
      field_name = "id"
      field_value = $input.endereco_cliente_id
      enforce_hidden_fields = false
      data = {}
    } as $endereco_cliente
  }

  response = $endereco_cliente
  guid = "DGj8BBv-gdFtcjIrWMhUzkXpp5E"
}