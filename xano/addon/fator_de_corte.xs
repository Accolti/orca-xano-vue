addon Fator_de_Corte {
  input {
    int Fator_de_Corte_id? {
      table = "Fator_de_Corte"
    }
  }

  stack {
    db.query Fator_de_Corte {
      where = $db.Fator_de_Corte.id ==? $input.Fator_de_Corte_id
      return = {type: "single"}
    }
  }

  guid = "8AECk7XJodiP-F2cms5MkNk0qO0"
}