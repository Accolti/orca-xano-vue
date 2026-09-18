// Delete telefone_cliente record.
query "telefone_cliente/{telefone_cliente_id}" verb=DELETE {
  api_group = "Default"

  input {
    int telefone_cliente_id? filters=min:1
  }

  stack {
    db.del Telefone_Cliente {
      field_name = "id"
      field_value = $input.telefone_cliente_id
    }
  }

  response = null
  guid = "DsMyNPolrA4n9yhNdPPdJ5HWK_o"
}