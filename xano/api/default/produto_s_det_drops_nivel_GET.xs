// Preenche as drops pela de produtos como base. Este item 
query produto_s_Det_drops_nivel verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    // Lista Nível
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
    
      where = $db.Produto.detalhe_id == 0
      eval = {
        nm_Material: $db.Material.nome
        nm_Classif : $db.Classificacao.nome
        nm_Linha   : $db.Linha.nome
        nm_Tipo    : $db.Tipo.nome
        nm_Nivel   : $db.Nivel.nome
      }
    
      return = {
        type : "aggregate"
        group: {id: $db.Produto.nivel_id, nome: $db.nm_Nivel}
      }
    
      output = ["id", "nome"]
    } as $Produto_1
  
    !conditional {
      if ($input.Eh_DropDown == false) {
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
        
          where = $db.Produto.detalhe_id == 0 && ($db.Material.nome|to_upper) ==? ($input.nmMaterial|to_upper) && ($db.Classificacao.nome|to_upper) ==? ($input.nmClassificacao|to_upper) && ($db.Linha.nome|to_upper) ==? ($input.nmLinha|to_upper) && ($db.Tipo.nome|to_upper) ==? ($input.nmTipo|to_upper) && ($db.Nivel.nome|to_upper) ==? ($input.nmNivel|to_upper)
          eval = {
            nm_Material: $db.Material.nome
            nm_Classif : $db.Classificacao.nome
            nm_Linha   : $db.Linha.nome
            nm_Tipo    : $db.Tipo.nome
            nm_Nivel   : $db.Nivel.nome
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
          ]
        
          addon = [
            {
              name : "Borda_Por_Material"
              input: {
                material_id: $output.material_id
                nomeBorda  : $input.nmBorda
              }
              as   : "_borda_por_material"
            }
            {
              name : "Tipo_FatorxFator_de_Corte"
              input: {
                material_id: $output.material_id
                linha_id   : $output.linha_id
                nmBorda    : $input.nmBorda|to_upper
              }
              as   : "_tipo_fatorxfator_de_corte"
            }
          ]
        } as $Produto_1
      }
    }
  }

  response = $Produto_1
  guid = "37xvuydDn78S2E0ME_qGswc7yKs"
}