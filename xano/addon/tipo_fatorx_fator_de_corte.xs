addon Tipo_FatorxFator_de_Corte {
  input {
    int material_id? {
      table = "Material"
    }
  
    int linha_id? {
      table = "Linha"
    }
  
    text nmBorda? filters=trim
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
    
      where = $db.Tipo_Fator.material_id == $input.material_id && $db.Tipo_Fator.linha_id ==? $input.linha_id && ($db.Borda.nome|to_upper) ==? ($input.nmBorda|to_upper)
      eval = {
        Larg_Mult: $db.Fator_de_Corte.Larg_Multiplo
        Comp_Mult: $db.Fator_de_Corte.Comp_Multiplo
        FC       : $db.Fator_de_Corte.valor
      }
    
      return = {type: "list"}
    }
  }

  guid = "MjPN8mMpiq_43HQfXUX-92nD_Qs"
}