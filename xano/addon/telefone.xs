addon Telefone {
  input {
    int Telefone_Cliente_id? {
      table = "Telefone_Cliente"
    }
  }

  stack {
    db.query Telefone_Cliente {
      where = $db.Telefone_Cliente.cliente_id == $input.Telefone_Cliente_id
      return = {type: "list"}
    }
  }

  guid = "GPPJ-LmBv9p8L--GzCxT088PaRU"
}