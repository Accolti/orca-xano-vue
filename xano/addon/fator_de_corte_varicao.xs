addon fator_de_corte_varicao {
  input {
  }

  stack {
    db.query Variacao {
      join = {
        Fator_de_Corte: {
          table: "Fator_de_Corte"
          where: $db.Variacao.fator_de_corte_id == $db.Fator_de_Corte.id
        }
      }
    
      return = {type: "list"}
    }
  }

  guid = "yM3S4VS9fZWS0fwOV3mEGHBMSVw"
}