// _2 pois a referencia a borda não é mais pelo nome, mas sim peo ID
addon Tipo_FatorxFator_de_Corte_2 {
  input {
    int material_id? {
      table = "Material"
    }
  
    int linha_id? {
      table = "Linha"
    }
  
    int borda_id? {
      table = "Borda"
    }
  }

  stack {
    db.query Tipo_Fator {
      join = {
        Material      : {
          table: "Material"
          where: $db.Tipo_Fator.material_id == $db.Material.id
        }
        Linha         : {
          table: "Linha"
          type : "left"
          where: $db.Tipo_Fator.linha_id ==? $db.Linha.id
        }
        Borda         : {
          table: "Borda"
          type : "left"
          where: $db.Tipo_Fator.borda_id ==? $db.Borda.id
        }
        Fator_de_Corte: {
          table: "Fator_de_Corte"
          where: $db.Tipo_Fator.fator_de_corte_id == $db.Fator_de_Corte.id
        }
      }
    
      where = $db.Tipo_Fator.material_id == $input.material_id && $db.Tipo_Fator.linha_id ==? $input.linha_id && $db.Borda.id ==? $input.borda_id
      eval = {
        Larg_Mult: $db.Fator_de_Corte.Larg_Multiplo
        Comp_Mult: $db.Fator_de_Corte.Comp_Multiplo
        FC       : $db.Fator_de_Corte.valor
      }
    
      return = {type: "list"}
    }
  }

  guid = "Au8qerU1Fju5PM5xhN8KL97SfFM"
}