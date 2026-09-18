// Preenche as drops pela de produtos como base. Este item 
query produto_c_Det_drops_material verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    // Lista Materiais
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
          where: $db.Produto.linha_id == $db.Linha.id
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
    
      where = $db.Produto.detalhe_id > 0
      sort = {ordem: "asc"}
      eval = {
        nm_Material: $db.Material.nome
        nm_Classif : $db.Classificacao.nome
        nm_Linha   : $db.Linha.nome
        nm_Tipo    : $db.Tipo.nome
        nm_Nivel   : $db.Nivel.nome
        ordem      : $db.Material.Ordenacao
      }
    
      return = {
        type : "aggregate"
        group: {
          id   : $db.Produto.material_id
          nome : $db.nm_Material
          ordem: $db.ordem
        }
      }
    
      output = ["id", "nome"]
    } as $Produto_1
  
    function.run Ret_TabMaeEFilhas_2 {
      input = {id_material: 0, id_organizacao: 1, nmMaterial: null}
    } as $countOthersSelects
  }

  response = {
    result1           : $Produto_1
    countOthersSelects: $countOthersSelects
  }

  guid = "u6vL2LfS6yNM5U1asIAUzRtMIks"
}