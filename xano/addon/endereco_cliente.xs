addon Endereco_Cliente {
  input {
    int cliente_id? {
      table = "Cliente"
    }
  }

  stack {
    db.query Endereco_Cliente {
      where = $db.Endereco_Cliente.cliente_id == $input.cliente_id
      sort = {Endereco_Cliente.created_at: "desc"}
      return = {type: "list"}
    }
  }

  guid = "ObldtAzWv9XLAe-uBP5HXbCUbyk"
}