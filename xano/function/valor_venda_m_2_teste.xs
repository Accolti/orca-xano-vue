// Valor de Venda por Metro Linear
function Valor_Venda_M2_teste {
  input {
    // Area calculada pelo FC
    decimal Area_FC?
  
    // Largura: informar a largura já com o fator de corte
    decimal Larg_FC?
  
    // Comprimento inf pelo cliente para calc da área
    decimal Comp_FC?
  
    decimal CustoM2?
  
    // Não entrar com valor em procentage. Enttrar como exemplo 80.55 
    decimal Margem?
  
    decimal Frete_B2B?
    int Qtd_Unidades?=1
    decimal Custo_Borda?
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
  
    function.run Marguem_Multiplicadora {
      input = {Marguem: $input.Margem}
    } as $margem_Mult
  
    !debug.stop {
      value = $margem_Mult
    }
  
    var $Valor_Custo {
      value = $input.CustoM2
        |add:$input.Custo_Borda
        |multiply:$Area_Requerida
    }
  
    api.lambda {
      code = "const parseBRLNumber = (value) => { if (typeof value === 'number') { return isNaN(value) ? 0 : value; } if (typeof value !== 'string' || value.trim() === '') { return 0; } const cleanedString = value.replace(/\\./g, '').replace(',', '.'); const number = parseFloat(cleanedString); return isNaN(number) ? 0 : number; }; const areaInput = parseBRLNumber($input.Area_FC); const largura = parseBRLNumber($input.Larg_FC); const comprimento = parseBRLNumber($input.Comp_FC); const custoM2 = parseBRLNumber($input.CustoM2); const margemPercent = parseBRLNumber($input.Margem); const freteB2B = parseBRLNumber($input.Frete_B2B); const qtdUnidades = parseInt(parseBRLNumber($input.Qtd_Unidades), 10); const custoBorda = parseBRLNumber($input.Custo_Borda); const ipiPercent = parseBRLNumber($input.IPI); const impPercent = parseBRLNumber($input.IMP); const areaCalculada = largura * comprimento; const areaConsiderada = areaInput > 0 ? areaInput : areaCalculada; if (areaConsiderada <= 0 || custoM2 <= 0 || qtdUnidades <= 0) { return { error: 'Dados insuficientes para o cálculo. Verifique os valores de Área (ou Largura/Comprimento), Custo por M2 e Quantidade.', precoFinal: 0, detalhes: { areaConsiderada, custoM2, qtdUnidades } }; } const custoMaterialUnitario = areaConsiderada * custoM2; const custoBrutoUnitario = custoMaterialUnitario + custoBorda; const custoComMargemUnitario = custoBrutoUnitario * (1 + (margemPercent / 100)); const subtotal = custoComMargemUnitario * qtdUnidades; const valorIPI = subtotal * (ipiPercent / 100); const valorIMP = subtotal * (impPercent / 100); const totalComImpostos = subtotal + valorIPI + valorIMP; const precoFinal = totalComImpostos + freteB2B; return { precoFinal: precoFinal, detalhes: { areaConsiderada: areaConsiderada, custoBrutoUnitario: custoBrutoUnitario, custoComMargemUnitario: custoComMargemUnitario, subtotal: subtotal, valorIPI: valorIPI, valorIMP: valorIMP, totalComImpostos: totalComImpostos, frete: freteB2B, quantidade: qtdUnidades } };"
      timeout = 10
    } as $x1
  
    var $Valor_Custo_IPI {
      value = $Valor_Custo|multiply:($input.IPI|divide:100)
    }
  
    var $Valor_Custo_IMP {
      value = $Valor_Custo|multiply:($input.IMP|divide:100)
    }
  
    !debug.stop {
      value = $Valor_Custo_IPI
    }
  
    !debug.stop {
      value = $Valor_Custo
    }
  
    var.update $Valor_Custo {
      value = $Valor_Custo
        |add:$Valor_Custo_IMP
        |add:$Valor_Custo_IPI
    }
  
    !debug.stop {
      value = $Valor_Custo
    }
  
    function.run Valor_Venda {
      input = {
        Valor_Custo                 : $Valor_Custo
        Valor_Marguem_Multiplicadora: $margem_Mult
      }
    } as $Valor_de_Venda
  
    !debug.stop {
      value = $Valor_de_Venda
    }
  
    var $Valor_Lucro {
      value = $Valor_de_Venda|subtract:$Valor_Custo|round:2
    }
  
    var $Valor_Venda_FRT_Unit_B2B {
      value = $Valor_de_Venda
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
  
    conditional {
      if ($Valor_Custo_Total <= 750) {
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
    Valor_Custo_Unit         : $Valor_Custo
    Valor_Venda_Unit         : $Valor_de_Venda
    Valor_Lucro_Unit         : $Valor_Lucro
    Valor_Venda_Unit_B2B     : $Valor_Venda_FRT_Unit_B2B
    AreaFC                   : $Area_Requerida
    Qtd_Unidades             : $input.Qtd_Unidades
    Valor_Custo_Total        : $Valor_Custo_Total
    Valor_Venda_Total        : $Valor_Venda_Total
    Valor_Lucro_Total        : $Valor_Lucro_Total
    Valor_Venda_Total_FRT_B2B: $Valor_Venda_Total_FRT_B2B
    Valor_Custo_IPI          : $Valor_Custo_IPI
    Valor_Custo_IMP          : $Valor_Custo_IMP
    valor_venda_ipi_tot      : $valor_venda_ipi_tot
    valor_venda_imp_tot      : $valor_venda_imp_tot
    Valor_Venda_Total_B2B    : $Valor_Venda_Total_FRT_B2B
    margem                   : $input.Margem
  }

  guid = "K2FOn2Cj7Mzk5NtFTpAQOvR8FyU"
}