addon Produto {
  input {
    int Produto_id? {
      table = "Produto"
    }
  }

  stack {
    db.query Produto {
      where = $db.Produto.id == $input.Produto_id
      return = {type: "list"}
    }
  }

  guid = "z5T8wKZgXbp_i_MR2DC_sdUykko"
}