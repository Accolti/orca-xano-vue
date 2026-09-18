// Lista TODOS os produtos (ativos e inativos) com material/linha/tipo/nível e
// variações — usada pela tela de cadastro de produtos (dev tool, auth User).
// Isolado do fTodos_Produtos (que filtra ativo) para permitir reativar produtos.
query produtos_dev_lista verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Produto {
      join = {
        Material: {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Linha   : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo    : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel   : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Nivel.id
        }
      }
    
      sort = {Produto.id: "asc"}
      eval = {
        classificacao: $db.Material.nome
        descricao    : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome
        produto_id   : $db.Produto.id
        material_nome: $db.Material.nome
        linha_nome   : $db.Linha.nome
        tipo_nome    : $db.Tipo.nome
        nivel_nome   : $db.Nivel.nome
      }
    
      return = {type: "list", distinct: "yes"}
      output = [
        "id"
        "material_id"
        "classificacao_id"
        "linha_id"
        "tipo_id"
        "nivel_id"
        "valor"
        "com_medida_exata"
        "porcentagem_acrescimo"
        "Unidade"
        "Base_de_Calculo"
        "tipo_composto"
        "detalhe_id"
        "fator_de_corte_id"
        "ativo"
        "classificacao"
        "descricao"
        "produto_id"
        "material_nome"
        "linha_nome"
        "tipo_nome"
        "nivel_nome"
      ]
    
      addon = [
        {
          name : "Variacao_of_Detalhe"
          input: {detalhe_id: $output.detalhe_id}
          as   : "_variacao"
        }
      ]
    } as $todos
  }

  response = $todos
  guid = "OrcaKap-produtos-dev-lista"
}