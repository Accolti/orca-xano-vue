// Valor de Venda por Metro Linear
function Valor_Venda_Unidade {
  input {
    decimal Custo_Unidade?
  
    // Não entrar com valor em procentage. Enttrar como exemplo 80.55 
    decimal Margem?
  
    decimal Frete_B2B?
    int Qtd_Unidades?=1
  
    // Não colocar em porcentagem. Exemplo se for 10% colocar neste campo 10
    decimal IPI?
  
    // Não colocar em porcentagem. Se for 15.5% colocar 15.5
    decimal IMP?
  
    // Apenas um descritivo Ex. Colocar 60x90
    text Medida? filters=trim
  }

  stack {
    function.run Marguem_Multiplicadora {
      input = {Marguem: $input.Margem}
    } as $margem_Mult
  
    // Valor de Custo
    var $Valor_Custo {
      value = $input.Custo_Unidade
    }
  
    // Valor de Venda
    function.run Valor_Venda {
      input = {
        Valor_Custo                 : $Valor_Custo
        Valor_Marguem_Multiplicadora: $margem_Mult
      }
    } as $Valor_de_Venda
  
    var $Valor_Venda_Sem_Impostos {
      value = $Valor_de_Venda
    }
  
    var $Valor_Custo_IPI {
      value = $Valor_Custo
        |multiply:($input.IPI|divide:100)
        |round:2
    }
  
    var $Valor_Custo_IMP {
      value = $Valor_Custo|multiply:($input.IMP|divide:100)
    }
  
    // Valor de Custo acrescido da porcentagem de impostos
    var.update $Valor_Custo {
      value = $Valor_Custo
        |add:$Valor_Custo_IPI
        |add:$Valor_Custo_IMP
    }
  
    var $Valor_Venda_IPI {
      value = $Valor_de_Venda
        |multiply:($input.IPI|divide:100)
        |round:2
    }
  
    var $Valor_Venda_IMP {
      value = $Valor_de_Venda|multiply:($input.IMP|divide:100)
    }
  
    // Valor de Venda acrescido da porcentagem de impostos
    var.update $Valor_de_Venda {
      value = $Valor_de_Venda
        |add:$Valor_Venda_IPI
        |add:$Valor_Venda_IMP
        |round:2
        |round:2
    }
  
    var $Valor_Lucro {
      value = $Valor_de_Venda|subtract:$Valor_Custo|round:2
    }
  
    // Já Atribui o valor de venda caso o valor de custo seja > 750. Esse valor vai prevalecer.
    var $Valor_Venda_FRT_Unit_B2B {
      value = $Valor_de_Venda
    }
  
    var $Valor_Custo_Total {
      value = $Valor_Custo|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Custo_IPI_Total {
      value = $Valor_Custo_IPI|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Custo_IMP_Total {
      value = $Valor_Custo_IMP|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Venda_Total {
      value = $Valor_de_Venda|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Venda_IPI_Total {
      value = $Valor_Venda_IPI|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Venda_IMP_Total {
      value = $Valor_Venda_IMP|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Lucro_Total {
      value = $Valor_Lucro|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Lucro_Total {
      value = $Valor_Lucro|multiply:$input.Qtd_Unidades
    }
  
    var $Valor_Lucro_Total {
      value = $Valor_Lucro|multiply:$input.Qtd_Unidades
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
          value = $Valor_Venda_Total_FRT_B2B|divide:$input.Qtd_Unidades
        }
      }
    }
  }

  response = {
    Valor_Custo              : $input.Custo_Unidade
    Valor_Custo_IPI          : $Valor_Custo_IPI
    Valor_Custo_IMP          : $Valor_Custo_IMP
    Valor_Custo_C_Taxas      : $Valor_Custo
    Valor_Venda              : $Valor_Venda_Sem_Impostos
    Valor_Venda_IPI          : $Valor_Venda_IPI
    Valor_Venda_IMP          : $Valor_Venda_IMP
    Valor_Venda_C_Taxas      : $Valor_de_Venda
    Lucro_unitario           : $Valor_Lucro
    Qtd_Unidades             : $input.Qtd_Unidades
    Valor_Custo_IPI_Total    : $Valor_Custo_IPI_Total
    Valor_Custo_IMP_Total    : $Valor_Custo_IMP_Total
    Valor_Custo_C_Taxas_Total: $Valor_Custo_Total
    Valor_Venda_IPI_Total    : $Valor_Venda_IPI_Total
    Valor_Venda_IMP_Total    : $Valor_Venda_IMP_Total
    Valor_Venda_C_Taxas_Total: $Valor_Venda_Total
    Valor_Venda_FRT_Unit_B2B : $Valor_Venda_FRT_Unit_B2B
    Valor_Venda_Total_FRT_B2B: $Valor_Venda_Total_FRT_B2B
    Valor_Lucro_Total        : $Valor_Lucro_Total
    Valor_Custo_Unit         : $Valor_Custo
    Valor_Venda_Unit         : $Valor_de_Venda
    Valor_Lucro_Unit         : $Valor_Lucro
    Valor_Venda_Unit_B2B     : $Valor_Venda_FRT_Unit_B2B
    Valor_Custo_Total        : $Valor_Custo_Total
    Valor_Venda_Total        : $Valor_Venda_Total
    Valor_Venda_Total_B2B    : $Valor_Venda_Total_FRT_B2B
    Medida                   : $input.Medida
    margem                   : $input.Margem
  }

  guid = "URC0RdOnq2_RyF-tn074TgnEw1s"
}