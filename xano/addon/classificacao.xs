addon Classificacao {
  input {
    int Classificacao_id? {
      table = "Classificacao"
    }
  }

  stack {
    db.query Classificacao {
      where = $db.Classificacao.id == $input.Classificacao_id
      return = {type: "single"}
    }
  }

  guid = "rh6UEaNXOgG9Vre4JLB56Z83cpY"
}