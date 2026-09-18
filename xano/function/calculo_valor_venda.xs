// Valor de Venda por Metro Linear
function Calculo_Valor_Venda {
  input {
    // Valor já submetido a area + Borda e Acessorios
    decimal Custo_Calculado?
  
    // Não entrar com valor em procentagem. Entrar como exemplo 80.55 
    decimal Margem?
  
    decimal IPI?
    decimal IMP?
  }

  stack {
    function.run Marguem_Multiplicadora {
      input = {Marguem: $input.Margem}
    } as $margem_Mult
  
    !debug.stop {
      value = $margem_Mult
    }
  
    var $Valor_Custo {
      value = $input.Custo_Calculado
    }
  
    var $Valor_Venda {
      value = $input.Custo_Calculado|multiply:$margem_Mult
    }
  
    var $Valor_Custo_IPI {
      value = $Valor_Custo|multiply:($input.IPI|divide:100)
    }
  
    var $Valor_Custo_IMP {
      value = $Valor_Custo|multiply:($input.IMP|divide:100)
    }
  
    var.update $Valor_Custo {
      value = $Valor_Custo
        |add:$Valor_Custo_IMP
        |add:$Valor_Custo_IPI
    }
  
    !debug.stop {
      value = $Valor_Custo
    }
  
    var $Valor_Venda_IPI {
      value = $Valor_Venda|multiply:($input.IPI|divide:100)
    }
  
    var $Valor_Venda_IMP {
      value = $Valor_Venda|multiply:($input.IMP|divide:100)
    }
  
    var.update $Valor_Venda {
      value = $Valor_Venda
        |add:$Valor_Venda_IMP
        |add:$Valor_Venda_IPI
    }
  
    !debug.stop {
      value = $Valor_Venda
    }
  
    !debug.stop {
      value = $Valor_Venda|subtract:$Valor_Custo
    }
  
    function.run fCalculaFrete {
      input = {valor_total_compra: $Valor_Custo, user_id: $auth.id}
    } as $freteB2B
  
    function.run Valor_Venda {
      input = {
        Valor_Custo                 : $Valor_Custo
        Valor_Marguem_Multiplicadora: $margem_Mult
      }
    } as $Valor_de_Venda
  
    var $Valor_Lucro {
      value = $Valor_de_Venda|subtract:$Valor_Custo|round:2
    }
  
    !debug.stop {
      value = $Valor_Lucro
    }
  
    var $Valor_Venda_FRT_B2B {
      value = $Valor_de_Venda
    }
  
    var $valor_venda_ipi_tot {
      value = $Valor_Custo_IPI
        |multiply:$margem_Mult
        |multiply:$input.Qtd_Unidades
    }
  
    var $valor_venda_ipi_tot {
      value = $Valor_Custo_IPI
        |multiply:$margem_Mult
        |multiply:$input.Qtd_Unidades
    }
  
    var $valor_venda_imp_tot {
      value = $Valor_Custo_IMP
        |multiply:$margem_Mult
        |multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Custo_Total {
      value = $Valor_Custo|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Venda_Total {
      value = $Valor_de_Venda|multiply:$input.Qtd_Unidades
    }
  
    !var $Valor_Lucro_Total {
      value = $Valor_Lucro|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Lucro_Total {
      value = $Valor_Lucro|multiply:$input.Qtd_Unidades
    }
  
    !var $Valor_Lucro_Total {
      value = $Valor_Lucro
        |multiply:$input.Qtd_Unidades
        |round:2
    }
  
    var $Valor_Venda_Total_FRT_B2B {
      value = $Valor_Venda_Total
    }
  
    !debug.stop {
      value = $Valor_Venda_Total_FRT_B2B
    }
  
    !function.run fCalculaFrete {
      input = {valor_total_compra: $Valor_Custo_Total}
    } as $freteB2B
  
    var.update $Valor_Venda_Total_FRT_B2B {
      value = $Valor_Venda_Total|add:$freteB2B
    }
  
    var.update $Valor_Venda_FRT_B2B {
      value = $Valor_Venda_Total_FRT_B2B|divide:$input.Qtd_Unidades
    }
  
    !conditional {
      if ($Valor_Custo_Total <= 750) {
        var.update $Valor_Venda_Total_FRT_B2B {
          value = $Valor_Venda_Total|add:$input.Frete_B2B
        }
      
        var.update $Valor_Venda_FRT_B2B {
          value = $Valor_Venda_Total_FRT_B2B|divide:$input.Qtd_Unidades
        }
      }
    }
  }

  response = {
    Valor_Custo_Unit         : $Valor_Custo
    Valor_Venda_Unit         : $Valor_de_Venda
    Valor_Lucro_Unit         : $Valor_Lucro
    Valor_Venda_Unit_B2B     : $Valor_Venda_FRT_B2B
    AreaFC                   : $Area_Requerida
    Qtd_Unidades             : $input.Qtd_Unidades
    Valor_Custo_Total        : $Valor_Custo_Total
    Valor_Venda_Total        : $Valor_Venda_Total
    Valor_Lucro_Total        : $Valor_Lucro_Total
    Valor_Venda_Total_FRT_B2B: $Valor_Venda_Total_FRT_B2B
    Valor_Custo_IPI          : $Valor_Custo_IPI
    Valor_Custo_IMP          : $Valor_Custo_IMP
    Valor_Venda_ipi_tot      : $valor_venda_ipi_tot
    Valor_Venda_imp_tot      : $valor_venda_imp_tot
    Valor_Venda_Total_B2B    : $Valor_Venda_Total_FRT_B2B
    margem                   : $input.Margem
    Valor_Frete_B2B          : $freteB2B
  }

  guid = "DTcofJzBwlEYoOzpUV_UDnNCuNE"
}