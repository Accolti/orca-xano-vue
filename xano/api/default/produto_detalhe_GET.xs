// Query all material records
query produto_detalhe verb=GET {
  api_group = "Default"

  input {
    int material_id? {
      table = "Material"
    }
  
    int classificacao_id? {
      table = "Classificacao"
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
  
    int borda_id? {
      table = "Borda"
    }
  }

  stack {
    db.query Produto {
      join = {
        Material     : {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Classificacao: {
          table: "Classificacao"
          where: $db.Produto.classificacao_id ==? $db.Classificacao.id
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
    
      where = $db.Produto.detalhe_id > 0 && $db.Material.id ==? $input.material_id && $db.Classificacao.id ==? $input.classificacao_id && $db.Linha.id ==? $input.linha_id && $db.Tipo.id ==? $input.tipo_id && $db.Nivel.id ==? $input.nivel_id
      eval = {
        nm_Material : $db.Material.nome
        nm_Classif  : $db.Classificacao.nome
        nm_Linha    : $db.Linha.nome
        nm_Tipo     : $db.Tipo.nome
        nm_Nivel    : $db.Nivel.nome
        Produto_nome: $db.Material.nome
        ncm         : $db.Material.ncm
        imp         : $db.Material.imp
        ipi         : $db.Material.ipi
        peso        : $db.Material.peso
        st          : $db.Material.st
        nac         : $db.Material.nac
        obs         : $db.Material.Observacao
      }
    
      return = {type: "list"}
      output = [
        "id"
        "material_id"
        "classificacao_id"
        "linha_id"
        "tipo_id"
        "nivel_id"
        "valor"
        "Unidade"
        "Base_de_Calculo"
        "detalhe_id"
        "nm_Material"
        "nm_Classif"
        "nm_Linha"
        "nm_Tipo"
        "nm_Nivel"
        "Produto_nome"
        "ncm"
        "imp"
        "ipi"
        "peso"
        "st"
        "nac"
        "obs"
      ]
    
      addon = [
        {
          name  : "Variacao_of_Detalhe"
          output: [
            "id"
            "comp"
            "larg"
            "LxC"
            "qtd_kit"
            "valor_custo"
            "modelo"
            "variacao"
            "cor"
          ]
          input : {detalhe_id: $output.detalhe_id}
          as    : "_variacao_of_detalhe"
        }
        {
          name : "Borda_Por_Material"
          input: {
            material_id: $output.material_id
            nomeBorda  : $input.nmBorda
          }
          as   : "_borda_por_material"
        }
        {
          name : "Tipo_FatorxFator_de_Corte_2"
          input: {
            material_id: $input.material_id
            linha_id   : $input.linha_id
            borda_id   : $input.borda_id
          }
          as   : "_tipo_fatorxfator_de_corte_2"
        }
      ]
    } as $Produto_1
  
    !debug.stop {
      value = $Produto_1
    }
  
    var $nmProduto {
      value = ""
    }
  
    foreach ($Produto_1) {
      each as $item {
        var.update $nmProduto {
          value = $item.nm_Material
        }
      
        conditional {
          if ($item.nm_Linha != null) {
            var.update $nmProduto {
              value = $nmProduto|concat:$item.nm_Linha:" "
            }
          }
        }
      
        conditional {
          if ($item.nm_Tipo != null) {
            var.update $nmProduto {
              value = $nmProduto|concat:$item.nm_Tipo:" "
            }
          }
        }
      
        conditional {
          if ($item.nm_Nivel != null) {
            var.update $nmProduto {
              value = $nmProduto|concat:$item.nm_Nivel:" "
            }
          }
        }
      
        var.update $item.Produto_nome {
          value = $nmProduto
        }
      }
    }
  }

  response = $Produto_1
  guid = "iNwp7bJC86XR6mX2crc5JTH82s0"
}