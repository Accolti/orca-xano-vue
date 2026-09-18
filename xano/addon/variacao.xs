addon Variacao {
  input {
    int Variacao_id? {
      table = "Variacao"
    }
  }

  stack {
    db.query Variacao {
      join = {
        Tipo_Variacao: {
          table: "Tipo_Variacao"
          type : "left"
          where: $db.Variacao.tipo_variacao_id ==? $db.Tipo_Variacao.id
        }
        Modelo       : {
          table: "Modelo"
          type : "left"
          where: $db.Variacao.modelo_id ==? $db.Modelo.id
        }
        Cor          : {
          table: "Cor"
          type : "left"
          where: $db.Variacao.cor_id ==? $db.Cor.id
        }
      }
    
      where = $db.Variacao.id == $input.Variacao_id
      eval = {
        tipo  : $db.Tipo_Variacao.Descricao
        modelo: $db.Modelo.Descricao
        cor   : $db.Cor.Descricao
      }
    
      return = {type: "single"}
      output = [
        "id"
        "created_at"
        "detalhe_id"
        "tipo_variacao_id"
        "comp"
        "larg"
        "modelo_id"
        "LxC"
        "qtd_kit"
        "valor_custo"
        "cor_id"
        "tipo"
        "modelo"
        "cor"
      ]
    }
  }

  guid = "Pps9XfzFKYDUQHqeeVFIGf9CC7U"
}