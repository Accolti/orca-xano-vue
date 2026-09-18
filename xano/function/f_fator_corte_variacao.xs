function f_fator_corte_variacao {
  input {
    int variacao_id? {
      table = "Variacao"
    }
  }

  stack {
    db.query Variacao {
      join = {
        FC: {
          table: "Fator_de_Corte"
          where: $db.Variacao.fator_de_corte_id == $db.FC.id
        }
      }
    
      where = $db.Variacao.id == $input.variacao_id && $db.Variacao.ativo == true
      eval = {
        larg_base     : $db.FC.larg_base
        comp_corte    : $db.FC.comp_corte
        tam_rolo_total: $db.FC.tam_total
      }
    
      return = {type: "list"}
      output = ["larg_base", "comp_corte", "tam_rolo_total"]
    } as $Variacao1
  
    precondition (($Variacao1|count) > 0) {
      error_type = "notfound"
      error = "Variação desativada."
    }
  }

  response = $Variacao1
  guid = "dEDHBkTbW0LYu_T6VbtFB0lEy6I"
}