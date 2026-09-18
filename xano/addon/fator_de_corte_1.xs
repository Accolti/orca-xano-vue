addon Fator_de_Corte_1 {
  input {
    int Fator_de_Corte_id? {
      table = "Fator_de_Corte"
    }
  }

  stack {
    db.query Fator_de_Corte {
      where = $db.Fator_de_Corte.id == $input.Fator_de_Corte_id
      return = {type: "single"}
    }
  }

  guid = "7vjUk8J7n7bYLel_0O6FSqTbDUw"
}