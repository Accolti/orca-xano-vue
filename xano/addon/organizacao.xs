addon Organizacao {
  input {
    int Organizacao_id? {
      table = "Organizacao"
    }
  }

  stack {
    db.query Organizacao {
      where = $db.Organizacao.id == $input.Organizacao_id
      return = {type: "single"}
    }
  }

  guid = "L9tPJNDl9LepaIBkwJ1fD10PoIc"
}