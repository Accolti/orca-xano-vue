addon Telefone_Cliente_of_Cliente {
  input {
    int cliente_id? {
      table = "Cliente"
    }
  }

  stack {
    db.query Telefone_Cliente {
      join = {
        Tipo_Telefone: {
          table: "Tipo_Telefone"
          where: $db.Telefone_Cliente.tipo_telefone_id == $db.Tipo_Telefone.id
        }
      }
    
      where = $db.Telefone_Cliente.cliente_id == $input.cliente_id
      eval = {descricao: $db.Tipo_Telefone.descricao}
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "cliente_id"
        "tipo_telefone_id"
        "telefone"
        "descricao"
      ]
    }
  }

  guid = "xTDbrtlsZGu5vZBMlap7GXhXXPA"
}