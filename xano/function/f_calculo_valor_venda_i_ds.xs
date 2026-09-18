function f_CalculoValorVenda_IDs {
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
  
    // True para  simular com várias marguens
    bool bSimulaMargens?
  }

  stack {
    var $material {
      value = $input.nmMaterial
    }
  
    function.run Ret_TabMaeEFilhas {
      input = {
        id_material   : 0
        id_organizacao: 1
        nmMaterial    : $input.nmMaterial
      }
    } as $func_2
  
    var $nivel {
      value = $input.nmNivel
    }
  
    !debug.stop {
      value = $func_2
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
  
    var $borda {
      value = $input.nmBorda
    }
  
    !var.update $linha {
      value = ""
    }
  
    // pergunta-se: o material tem BORDA? 
    conditional {
      if (($func_2.Material_1.Borda|first) < "1") {
        var.update $borda {
          value = ""
        }
      }
    }
  
    // pergunta-se: o material tem LiNHA? 
    conditional {
      if (($func_2.Material_1.Linha|first) < "1") {
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
  
    // pergunta-se: o material tem NIVEL? 
    conditional {
      if (($func_2.Material_1.Nivel|first) < "1") {
        var.update $nivel {
          value = ""
        }
      
        // pergunta-se: o material tem TIPO? 
        conditional {
          if (($func_2.Material_1.Tipo|first) < "1") {
          }
        }
      
        var.update $tipo {
          value = ""
        }
      }
    }
  
    !debug.stop {
      value = $nivel
    }
  
    !db.query Borda {
      join = {
        Material: {
          table: "Material"
          where: ($db.Material.nome|to_upper) == ($input.nmMaterial|to_upper) && $db.Borda.material_id == $db.Material.id
        }
      }
    
      where = ($db.Borda.nome|to_upper) == ($input.nmBorda|to_upper)
      return = {type: "list"}
    } as $Borda1
  
    !var $borda_id {
      value = $Borda1.id|first
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
    
      where = ($db.Material.nome|to_upper) == ($material|to_upper) && ($db.Classificacao.nome|to_upper) ==? ($input.nmClassificacao|to_upper) && ($db.Linha.nome|to_upper) ==? ($linha|to_upper) && ($db.Tipo.nome|to_upper) ==? ($tipo|to_upper) && ($db.Nivel.nome|to_upper) ==? ($nivel|to_upper)
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
  
    !debug.stop {
      value = $Tipo_Fator_1
    }
  
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
  
    var $custo_MP {
      value = $Produto_2.valor|first
    }
  
    !debug.stop {
      value = $custo_MP
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
  
    var $vlr_venda_m2 {
      value = 0
    }
  
    conditional {
      if (($input.nmClassificacao|to_upper) == "PERSONALIZADO") {
        var $FC {
          value = $Tipo_Fator_1._fator_de_corte.valor
        }
      
        !debug.stop {
          value = $FC
        }
      
        function.run f_retorna_fc {
          input = {comp: $input.comp, larg: $input.larg, fc: $FC}
        } as $new_fc
      
        var.update $newComp {
          value = $new_fc.new_comp
        }
      
        var.update $newLarg {
          value = $new_fc.new_larg
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
  
    var.update $vlr_venda_m2 {
      value = $func_1.Valor_Venda_Total_B2B
        |divide:($input.larg|multiply:$input.comp)
    }
  
    !debug.stop {
      value = $vlr_venda_m2
    }
  
    var $cotacoes {
      value = []
    }
  
    var $cotacoes {
      value = []
    }
  
    // Simulação de cotações para mostrar o range de 50 a 100%
    conditional {
      if ($input.bSimulaMargens) {
        var $Margens {
          value = []
            |push:50
            |push:60
            |push:70
            |push:80
            |push:90
            |push:100
        }
      
        !debug.stop {
          value = $Margens
        }
      
        foreach ($Margens) {
          each as $mar {
            function.run Valor_Venda_M2 {
              input = {
                Area_FC     : 0
                Larg_FC     : $newLarg
                Comp_FC     : $newComp
                CustoM2     : $custo_MP
                Margem      : $mar
                Frete_B2B   : $input.frete_b2b
                Qtd_Unidades: $input.quantidade
                Custo_Borda : $custo_borda
                IPI         : $input.IPI
                IMP         : $input.IMP
              }
            } as $valores
          
            var.update $cotacoes {
              value = $cotacoes|append:$valores:""
            }
          
            !debug.stop {
              value = $cotacoes
            }
          }
        }
      }
    }
  }

  response = {
    comp        : $input.comp
    larg        : $input.larg
    CompFC      : $newComp
    LargFC      : $newLarg
    frete_b2b   : $input.frete_b2b
    cst_borda   : $custo_borda
    margem      : $input.margem
    vlr_venda_m2: $vlr_venda_m2
    Produto_2   : $Produto_2
    Tipo_Fator_1: $Tipo_Fator_1
    func_1      : $func_1
    simulacao   : $cotacoes
    mae_filhas  : $func_2
  }

  history = 10
  guid = "y_iGAoavr5unpRDmVp2FKNPiTcQ"
}