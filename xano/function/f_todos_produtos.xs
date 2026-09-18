function fTodos_Produtos {
  input {
    int produto_id? {
      table = "Produto"
    }
  
    int material_id? {
      table = "Material"
    }
  
    int linha_id? {
      table = "Linha"
    }
  
    int tipo_id? {
      table = "Tipo"
    }
  
    int nivel_id? {
      table = "Nivel"
    }
  
    int detalhe_id? {
      table = "Detalhe"
    }
  }

  stack {
    db.query Produto {
      join = {
        Classificacao: {
          table: "Classificacao"
          type : "left"
          where: $db.Produto.classificacao_id ==? $db.Classificacao.id
        }
        Material     : {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id && $db.Material.ativo == true
        }
        Linha        : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo         : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel        : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Nivel.id
        }
      }
    
      where = $db.Produto.id ==? $input.produto_id && $db.Produto.detalhe_id ==? $input.detalhe_id && $db.Produto.material_id ==? $input.material_id && $db.Produto.linha_id ==? $input.linha_id && $db.Produto.tipo_id ==? $input.tipo_id && $db.Produto.nivel_id ==? $input.nivel_id && $db.Produto.ativo == true
      eval = {
        classificacao: $db.Classificacao.nome
        descricao    : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome
        produto_id   : $db.Produto.id
        material_nome: $db.Material.nome
        linha_nome   : $db.Linha.nome
        tipo_nome    : $db.Tipo.nome
        nivel_nome   : $db.Nivel.nome
        base_calculo : $db.Produto.Base_de_Calculo
        und_produto  : $db.Produto.Unidade
      }
    
      return = {type: "list", distinct: "yes"}
      output = [
        "material_id"
        "classificacao_id"
        "linha_id"
        "tipo_id"
        "nivel_id"
        "valor"
        "ativo"
        "com_medida_exata"
        "porcentagem_acrescimo"
        "Unidade"
        "Base_de_Calculo"
        "tipo_composto"
        "detalhe_id"
        "fator_de_corte_id"
        "classificacao"
        "descricao"
        "produto_id"
        "material_nome"
        "linha_nome"
        "tipo_nome"
        "nivel_nome"
        "base_calculo"
        "und_produto"
      ]
    
      addon = [
        {
          name : "Variacao_of_Detalhe"
          input: {detalhe_id: $output.detalhe_id}
          as   : "_variacao"
        }
      ]
    } as $todos_produtos
  }

  response = $todos_produtos
  guid = "XMDXoILTbYw9aTvFC04q9KTY6Go"
}