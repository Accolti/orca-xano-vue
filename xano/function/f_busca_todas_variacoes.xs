function fBuscaTodasVariacoes {
  input {
  }

  stack {
    db.query Variacao {
      join = {
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
        Modelo       : {
          table: "Modelo"
          type : "left"
          where: $db.Variacao.modelo_id ==? $db.Modelo.id
        }
      }
    
      sort = {Variacao.id: "asc"}
      eval = {
        cor      : $db.Cor.Descricao
        descricao: $db.Detalhe.Descricao|concat:" "|concat:$db.Variacao.LxC|concat:" "|concat:$db.Modelo.Descricao|concat:" "|concat:$db.Cor.Descricao
      }
    
      return = {type: "list"}
      output = [
        "id"
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
        "cor"
        "descricao"
        "variacao_id"
      ]
    } as $Variacao1
  }

  response = $Variacao1
  guid = "IK-X38Whm8JxNBskXkkpAuZz4T0"
}