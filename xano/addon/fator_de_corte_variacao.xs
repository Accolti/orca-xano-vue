// retorna o vator de corte das variações
addon fator_de_corte_variacao {
  input {
    int variacao_id? {
      table = "Variacao"
    }
  }

  stack {
    db.query Fator_de_Corte {
      join = {
        Variacao: {
          table: "Variacao"
          type : "right"
          where: $db.Fator_de_Corte.id ==? $db.Variacao.fator_de_corte_id && $db.Variacao.ativo == true
        }
      }
    
      where = $db.Variacao.id == $input.variacao_id
      return = {type: "list"}
    }
  }

  guid = "IA4EHC6gfHJcAz0-H3l7x5p381U"
}