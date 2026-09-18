query CalculoValorVenda_IDs_2 verb=GET {
  api_group = "Default"

  input {
    decimal comp
    decimal larg
    text nmMaterial? filters=trim
    text nmClassificacao? filters=trim
    text nmTipo? filters=trim
    text nmLinha? filters=trim
    text nmNivel? filters=trim
    text nmBorda? filters=trim
    decimal margem?
    decimal frete_b2b?
    int quantidade?=1
    decimal IPI?
    decimal IMP?
  }

  stack {
    function.run Ret_TabMaeEFilhas {
      input = {
        id_material   : 0
        id_organizacao: 1
        nmMaterial    : $input.nmMaterial
      }
    } as $func_2
  
    var $material {
      value = $input.nmMaterial
    }
  
    var $classificacao {
      value = $input.nmClassificacao
    }
  
    var $tipo {
      value = $input.nmTipo
    }
  
    var $linha {
      value = $input.nmLinha
    }
  
    var $nivel {
      value = $input.nmNivel
    }
  
    var $borda {
      value = $input.nmBorda
    }
  
    // pergunta-se: o material tem LiNHA? 
    conditional {
      if (($func_2.Material_1.Linha|first) < "1") {
        var.update $linha {
          value = ""
        }
      }
    }
  
    // pergunta-se: o material tem TIPO? 
    conditional {
      if (($func_2.Material_1.Tipo|first) < "1") {
        var.update $tipo {
          value = ""
        }
      }
    }
  
    // pergunta-se: o material tem NIVEL? 
    conditional {
      if (($func_2.Material_1.Nivel|first) < "1") {
        var.update $nivel {
          value = ""
        }
      }
    }
  
    // pergunta-se: o material tem BORDA? 
    conditional {
      if (($func_2.Material_1.Borda|first) < "1") {
        var.update $borda {
          value = ""
        }
      }
    }
  
    // pergunta-se: o material tem TIPO? 
    conditional {
      if (($input.nmMaterial|to_upper) == "VINIL" && (($input.nmTipo|to_upper) == "LISO")) {
        var.update $nivel {
          value = ""
        }
      }
    }
  
    !debug.stop {
      value = $nivel
    }
  
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
    
      where = ($db.Material.nome|to_upper) == ($material|to_upper) && ($db.Classificacao.nome|to_upper) == ($input.nmClassificacao|to_upper) && ($db.Linha.nome|to_upper) ==? ($linha|to_upper) && ($db.Tipo.nome|to_upper) ==? ($tipo|to_upper) && ($db.Nivel.nome|to_upper) ==? ($nivel|to_upper)
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
  
    !debug.stop {
      value = $Produto_2
    }
  
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
    
      where = ($db.Borda.nome|to_upper) == ($borda|to_upper) && ($db.Material.nome|to_upper) == ($material|to_upper) && ($db.Linha.nome|to_upper) ==? ($linha|to_upper)
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
  
    var.update $custo_borda {
      value = $Produto_2._borda_por_material.valor|first
    }
  
    conditional {
      if ($custo_borda|is_object) {
        var.update $custo_borda {
          value = 0
        }
      }
    }
  
    !conditional {
      if ($Produto_2.detalhe_id > 0) {
        conditional {
          if (($input.nmMaterial|to_upper) == "VINIL") {
          }
        }
      }
    
      else {
        var $custo_borda {
          value = $Produto_2._borda_por_material.valor|first|get:"":0
        }
      }
    }
  
    var $custo_MP {
      value = $Produto_2.valor|first
    }
  
    var $Comp_Maior {
      value = 0
    }
  
    var $Larg_Maior {
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
  
    conditional {
      if (($input.nmClassificacao|to_upper) == "PERSONALIZADO") {
        var $FC {
          value = $Tipo_Fator_1._fator_de_corte.valor
        }
      
        // Fator de Corte Máximo
        var $fc_max {
          value = $FC|last
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
          each as $item2 {
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
            }
          }
        }
      }
    
      else {
        var.update $newComp {
          value = $input.comp
        }
      
        var.update $newLarg {
          value = $input.larg
        }
      }
    }
  
    var $Unidade_de_Calculo {
      value = $Produto_2.Unidade|first
    }
  
    function.run Valor_Venda_M2 {
      input = {
        Area_FC     : 0
        Larg_FC     : $newLarg
        Comp_FC     : $newComp
        CustoM2     : $custo_MP
        Margem      : $input.margem
        Frete_B2B   : $input.frete_b2b
        Qtd_Unidades: $input.quantidade
        Custo_Borda : $custo_borda
        IPI         : $input.IPI
        IMP         : $input.IMP
      }
    } as $func_1
  }

  response = {
    Produto_2   : $Produto_2
    Tipo_Fator_1: $Tipo_Fator_1
    CompFC      : $newComp
    LargFC      : $newLarg
    cst_borda   : $custo_borda
    func_1      : $func_1
  }

  guid = "sxILOwByJRnzEGcylB468vqi4WY"
}