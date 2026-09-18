addon Variacao_of_Detalhe {
  input {
    int detalhe_id? {
      table = "Detalhe"
    }
  }

  stack {
    db.query Variacao {
      join = {
        Modelo       : {
          table: "Modelo"
          type : "left"
          where: $db.Variacao.modelo_id ==? $db.Modelo.id
        }
        Tipo_Variacao: {
          table: "Tipo_Variacao"
          type : "left"
          where: $db.Variacao.tipo_variacao_id ==? $db.Tipo_Variacao.id
        }
        Cor          : {
          table: "Cor"
          type : "left"
          where: $db.Variacao.cor_id ==? $db.Cor.id
        }
        Detalhe      : {
          table: "Detalhe"
          where: $db.Variacao.detalhe_id == $db.Detalhe.id
        }
      }
    
      where = $db.Variacao.detalhe_id == $input.detalhe_id
      sort = {Variacao.ordem: "asc"}
      eval = {
        modelo   : $db.Modelo.Descricao
        variacao : $db.Tipo_Variacao.Descricao
        cor      : $db.Cor.Descricao
        descricao: $db.Detalhe.Descricao|concat:" "|concat:$db.Tipo_Variacao.Descricao|concat:" "|concat:$db.Variacao.LxC|concat:" "|concat:$db.Cor.Descricao
      }
    
      return = {type: "list"}
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
        "fator_de_corte"
        "ordem"
        "modelo"
        "variacao"
        "cor"
        "descricao"
      ]
    }
  }

  guid = "gkriN9Sj5i9I2Y4EAqu40KCmpuA"
}