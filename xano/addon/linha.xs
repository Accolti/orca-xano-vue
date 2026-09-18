addon Linha {
  input {
    int Linha_id? {
      table = "Linha"
    }
  }

  stack {
    db.query Linha {
      where = $db.Linha.id == $input.Linha_id
      return = {type: "single"}
    }
  }

  guid = "Kqrx7QedjHzkqkGJG_AfCSexlro"
}