query CalculoValorVenda verb=GET {
  api_group = "Admim"

  input {
    decimal comp
    decimal larg
    text nmMaterial? filters=trim
    text nmClassificacao? filters=trim
    text nmTipo? filters=trim
    text nmLinha? filters=trim
    text nmNivel? filters=trim
    text nmBorda? filters=trim
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
          where: $db.Produto.classificacao_id == $db.Classificacao.id
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
    
      where = ($db.Material.nome|to_upper) == ($input.nmMaterial|to_upper) && ($db.Classificacao.nome|to_upper) == ($input.nmClassificacao|to_upper) && ($db.Linha.nome|to_upper) ==? ($input.nmLinha|to_upper) && ($db.Tipo.nome|to_upper) ==? ($input.nmTipo|to_upper) && ($db.Nivel.nome|to_upper) ==? ($input.nmNivel|to_upper)
      return = {type: "list"}
      addon = [
        {
          name : "Borda_Por_Material"
          input: {
            material_id: $output.material_id
            nomeBorda  : $input.nmBorda
          }
          as   : "_borda_por_material"
        }
      ]
    } as $Produto_2
  
    db.query Tipo_Fator {
      join = {
        Material      : {
          table: "Material"
          where: $db.Tipo_Fator.material_id == $db.Material.id
        }
        Linha         : {
          table: "Linha"
          type : "left"
          where: $db.Tipo_Fator.linha_id ==? $db.Linha.id
        }
        Borda         : {
          table: "Borda"
          where: $db.Tipo_Fator.borda_id == $db.Borda.id
        }
        Fator_de_Corte: {
          table: "Fator_de_Corte"
          where: $db.Tipo_Fator.fator_de_corte_id == $db.Fator_de_Corte.id
        }
      }
    
      where = ($db.Borda.nome|to_upper) == ($input.nmBorda|to_upper) && ($db.Material.nome|to_upper) == ($input.nmMaterial|to_upper) && ($db.Linha.nome|to_upper) ==? ($input.nmLinha|to_upper)
      return = {type: "list"}
      addon = [
        {
          name : "Fator_de_Corte"
          input: {Fator_de_Corte_id: $output.fator_de_corte_id}
          as   : "_fator_de_corte"
        }
      ]
    } as $Tipo_Fator_1
  
    var $custo_borda {
      value = 0
    }
  
    var $FC {
      value = $Tipo_Fator_1._fator_de_corte.valor
    }
  
    var $custo_borda {
      value = $Produto_2._borda_por_material.valor|first
    }
  
    // Fator de Corte Máximo
    var $fc_max {
      value = $FC|last
    }
  
    var $Larg_Maior {
      value = 0
    }
  
    var $Comp_Maior {
      value = 0
    }
  
    var $newComp {
      value = 0
    }
  
    var $newLarg {
      value = 0
    }
  
    var $var_Teste {
      value = 0
    }
  
    foreach ($FC) {
      each as $item {
        conditional {
          if ($item >= $input.larg) {
            var.update $Larg_Maior {
              value = $item
            }
          
            break
          }
        }
      }
    }
  
    foreach ($FC) {
      each as $item2
    }
  
    conditional {
      if ($input.comp > $fc_max && $input.larg > $fc_max) {
        var.update $newComp {
          value = $input.comp
        }
      
        var.update $newLarg {
          value = $input.larg
        }
      }
    
      else {
        conditional {
          if ($Comp_Maior > 0 && $Larg_Maior > 0) {
            conditional {
              if (($Comp_Maior|multiply:$input.larg) > ($Larg_Maior|multiply:$input.comp)) {
                var.update $newComp {
                  value = $input.comp
                }
              
                var.update $newLarg {
                  value = $Larg_Maior
                }
              }
            
              else {
                var.update $newComp {
                  value = $Comp_Maior
                }
              
                var.update $newLarg {
                  value = $input.larg
                }
              }
            }
          }
        
          else {
            conditional {
              if ($Comp_Maior == 0) {
                var.update $newLarg {
                  value = $Larg_Maior
                }
              
                var.update $newComp {
                  value = $input.comp
                }
              }
            
              else {
                var.update $newComp {
                  value = $Comp_Maior
                }
              
                var.update $newLarg {
                  value = $input.larg
                }
              }
            }
          }
        }
      }
    }
  
    conditional {
      if ($item2 >= $input.comp) {
        var.update $Comp_Maior {
          value = $item2
        }
      
        !var.update $var_Teste {
          value = $newComp
        }
      
        break
      }
    }
  }

  response = {
    Produto_2   : $Produto_2
    Tipo_Fator_1: $Tipo_Fator_1
    CompFC      : $newComp
    LargFC      : $newLarg
    cst_borda   : $custo_borda
  }

  guid = "lPks9MDSWyC08Dobu8MPdqec6nQ"
}