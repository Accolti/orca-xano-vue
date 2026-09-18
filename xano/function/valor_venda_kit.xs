// Valor de Venda do KII
function Valor_Venda_Kit {
  input {
    // Area calculada pelo FC
    decimal Area_FC?
  
    // Largura: informar a largura já com o fator de corte
    decimal Larg_FC?
  
    // Comprimento inf pelo cliente para calc da área
    decimal Comp_FC?
  
    decimal CustoKit?
  
    // Não entrar com valor em procentage. Enttrar como exemplo 80.55 
    decimal Margem?
  
    decimal Frete_B2B?
    decimal larg_kit
    decimal comp_kit
  
    // De quantas peças o kit é formado
    int qtd_de_pecas_do_kit?
  
    decimal IPI?
    decimal IMP?
  }

  stack {
    var $Area_Requerida {
      value = 0
    }
  
    conditional {
      if ($input.Area_FC > 0) {
        var.update $Area_Requerida {
          value = $input.Area_FC
        }
      }
    
      else {
        var.update $Area_Requerida {
          value = $input.Larg_FC|multiply:$input.Comp_FC
        }
      }
    }
  
    // chamar a função Calc_QtdKits
    function.run Calc_QtdKits {
      input = {
        Area_Cliente    : $Area_Requerida
        Larg_Kit        : $input.larg_kit
        Comp_Kit        : $input.comp_kit
        Qtd_de_Pecas_Kit: $input.qtd_de_pecas_do_kit
      }
    } as $func_kits
  
    // Chamar a função Marguem_Multiplicadora que pega a marguem ex. 80 e transforma para 1.8 
    function.run Marguem_Multiplicadora {
      input = {Marguem: $input.Margem}
    } as $margem_Mult
  
    var $Valor_Custo {
      value = $input.CustoKit
    }
  
    // significa que valor_cst_ipi_unit = Valor_Custo*(IPI/100)
    var $valor_cst_ipi_unit {
      value = $Valor_Custo|multiply:($input.IPI|divide:100)
    }
  
    // significa que valor_cst_imp_unit = Valor_Custo*(IMP/100)
    var $valor_cst_imp_unit {
      value = $Valor_Custo|multiply:($input.IMP|divide:100)
    }
  
    // Calcula o valor de Valor_Venda = Valor_Custo * Margem (ex Marguem de 80 vai ser 1.8)
    function.run Valor_Venda {
      input = {
        Valor_Custo                 : $Valor_Custo
        Valor_Marguem_Multiplicadora: $margem_Mult
      }
    } as $Valor_de_Venda
  
    var $valor_venda_unit_ipi {
      value = $Valor_de_Venda|multiply:($input.IPI|divide:100)
    }
  
    var $valor_venda_unit_imp {
      value = $Valor_de_Venda|multiply:($input.IMP|divide:100)
    }
  
    var.update $Valor_Custo {
      value = $Valor_Custo
        |add:($valor_cst_ipi_unit|add:$valor_cst_imp_unit)
    }
  
    var.update $Valor_de_Venda {
      value = $Valor_de_Venda
        |add:($valor_venda_unit_ipi|add:$valor_venda_unit_imp)
    }
  
    var $Valor_Lucro {
      value = $Valor_de_Venda|subtract:$Valor_Custo
    }
  
    var $Valor_Venda_FRT_Unit_B2B {
      value = $Valor_de_Venda
    }
  
    var $Valor_Custo_Total {
      value = $Valor_Custo|multiply:$func_kits.Qtd_Kits
    }
  
    var $valor_cst_ipi_total {
      value = $valor_cst_ipi_unit|multiply:$func_kits.Qtd_Kits
    }
  
    var $valor_venda_ipi_total {
      value = $valor_venda_unit_ipi|multiply:$func_kits.Qtd_Kits
    }
  
    var $valor_cst_imp_total {
      value = $valor_cst_imp_unit|multiply:$func_kits.Qtd_Kits
    }
  
    var $valor_venda_imp_total {
      value = $valor_venda_unit_imp|multiply:$func_kits.Qtd_Kits
    }
  
    !debug.stop {
      value = $valor_venda_imp_total
    }
  
    var $Valor_Venda_Total {
      value = $Valor_de_Venda|multiply:$func_kits.Qtd_Kits
    }
  
    var $Valor_Lucro_Total {
      value = $Valor_Lucro|multiply:$func_kits.Qtd_Kits
    }
  
    var $Valor_Lucro_Total {
      value = $Valor_Lucro|multiply:$func_kits.Qtd_Kits
    }
  
    var $Valor_Lucro_Total {
      value = $Valor_Lucro|multiply:$func_kits.Qtd_Kits
    }
  
    var $Valor_Venda_Total_FRT_B2B {
      value = $Valor_Venda_Total
    }
  
    conditional {
      if ($Valor_Custo_Total < 750) {
        var.update $Valor_Venda_Total_FRT_B2B {
          value = $Valor_Venda_Total|add:$input.Frete_B2B
        }
      
        var.update $Valor_Venda_FRT_Unit_B2B {
          value = $Valor_Venda_Total_FRT_B2B|divide:$func_kits.Qtd_Kits
        }
      }
    }
  }

  response = {
    Valor_Custo_Unit         : $Valor_Custo
    Valor_Venda_Unit         : $Valor_de_Venda
    Valor_Lucro_Unit         : $Valor_Lucro
    Valor_Venda_Unit_B2B     : $Valor_Venda_FRT_Unit_B2B
    AreaFC                   : $Area_Requerida
    Valor_Custo_Total        : $Valor_Custo_Total
    Valor_Venda_Total        : $Valor_Venda_Total
    Valor_Lucro_Total        : $Valor_Lucro_Total
    Valor_Venda_Total_FRT_B2B: $Valor_Venda_Total_FRT_B2B
    Qtd_de_kits              : $func_kits.Qtd_Kits
    Area_1_Kit               : $func_kits.Area_Kit
    Area_Total_Kits          : $func_kits.Area_Total_Coberta_Kit
    valor_cst_ipi_unit       : $valor_cst_ipi_unit
    valor_cst_ipi_total      : $valor_cst_ipi_total
    valor_cst_imp_unit       : $valor_cst_imp_unit
    valor_cst_imp_total      : $valor_cst_imp_total
    valor_venda_unit_ipi     : $valor_venda_unit_ipi
    valor_venda_ipi_total    : $valor_venda_ipi_total
    valor_venda_unit_imp     : $valor_venda_unit_imp
    valor_venda_imp_total    : $valor_venda_imp_total
    Total_Pecas              : $func_kits.Total_Pecas
    Valor_Venda_Total_B2B    : $Valor_Venda_Total_FRT_B2B
    Qtd_Unidades             : $func_kits.Qtd_Kits
    margem                   : $input.Margem
  }

  guid = "-7hOphl9LHtrz_1BgvFmkab3t6U"
}