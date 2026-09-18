//  Valor de Venda por Metro Linear. Há duas variantes quando não há entrada de valor de borda então o calculo é feito levando em consideração a metragem necessária para atender a demanda da área que foi entrada.  Agora se houver valor de borda então é uma personalização.  O calculo é feito um pouco diferente. Pois ele pega as dimensões que o cliente quer é arredonda a largura para a padrão e o comprimento para o padrão e esse é a base do calculo de custo.
// 
// CUIDADO PARA QUE A FUNCAO NÃO CALCULE ERRADO! O VALOR DO CUSTO DE ENTRADA PRECISA ESTAR EM ML (METRO LINEAR) . SE FOR FORNECIDO O VALOR EM M2 COLOCAR O VALOR DO CUSTO NO CAMPO CUSTO_MP_GERAL ESPECIFICAR A BASE_CALC_MP em M2 (QUAL É A BASE QUE ESTÁ ESPECIFICADO A MP. RERALMENTE EM M2). NESTE CASO A FUNÇÃO VAI CONVERTER O VALOR DO CUSTO PARA O EQUIVALENTE EM ML.
function Valor_Venda_ML_OLD {
  input {
    decimal Area_do_Cliente?
  
    // Largura informada pelo cliente paa calculo da area
    decimal Larg_Cliente?
  
    // Comprimento inf pelo cliente para calc da área
    decimal Comp_Cliente?
  
    // Largura fixa do rolo ou peça. A outra dimemsão varia de metro em metro
    decimal Larg_Fixa
  
    // Tamanho tota do rolo ou peça
    decimal Tam_Total_Pca?
  
    // Valor de Custo da Matéria Prima 
    // O valor informado tem que ser em ML do produto específico. A grama é informada em M2 tem que ser transformada por Ml.
    // Ex. o rolo da grama tem 2x25m e é vendida por ml (1 em 1 m) se o m2 da grama custa 25(m2) o ml da grama será 50Ml pois o mínimo que é vendido é uma peça de 2x1, pois 1mL de grama tem 2m2.
    decimal Custo_MP_Geral?
  
    // Não entrar com valor em procentage. Enttrar como exemplo 80.55 
    decimal margem?
  
    decimal Frete_B2B?
    decimal Custo_Borda_ML?
  
    // É o fator de corte do comprimento para ML será de 1 em 1 m
    decimal FC_Comprimento?
  
    decimal IMP?
    decimal IPI?
  
    // Base de calculo da MP (Pode ser fornecida em ML ou M2). No caso se for M2 terá que ser convertida para ML.
    text Base_Calc_MP?=ML filters=trim
  }

  stack {
    !precondition ($input.Custo_Ml > 0 && $input.Custo_M2 == 0) {
      error_type = "badrequest"
      error = "XXA  FUNÇÃO SÓ PODE RECEBER CUSTO_ML OU CUSTO_m2"
    }
  
    !precondition ($input.Custo_Ml == 0 && $input.Custo_M2 > 0) {
      error_type = "badrequest"
      error = "A FUNÇÃO SÓ PODE RECEBER CUSTO_ML OU CUSTO_m2"
    }
  
    var $Custo_Mat_Prima {
      value = 0
    }
  
    var $CUSTO_METRO_LINEAR {
      value = 0
    }
  
    conditional {
      if (($input.Base_Calc_MP|to_upper) == "M2") {
        var.update $CUSTO_METRO_LINEAR {
          value = $input.Custo_MP_Geral|multiply:$input.Larg_Fixa
        }
      }
    
      else {
        var.update $CUSTO_METRO_LINEAR {
          value = $input.Custo_MP_Geral
        }
      }
    }
  
    !debug.stop {
      value = $CUSTO_METRO_LINEAR
    }
  
    var $Area_Requerida {
      value = 0
    }
  
    var $cst_IPI {
      value = $CUSTO_METRO_LINEAR|multiply:($input.IPI|divide:100)
    }
  
    !debug.stop {
      value = $cst_IPI
    }
  
    var $cst_IMP {
      value = $CUSTO_METRO_LINEAR|multiply:($input.IMP|divide:100)
    }
  
    var $Custo_Mat_Prima {
      value = $CUSTO_METRO_LINEAR|add:$cst_IPI|add:$cst_IMP
    }
  
    !debug.stop {
      value = $Custo_Mat_Prima
    }
  
    // Vou usar essas vaiáveis para testar qual a opção será a amais barata para o cliente.
    // Vou comparar se o corte será na horizontal ou vertical
    var $Comp {
      value = $input.Comp_Cliente
    }
  
    var $Larg {
      value = $input.Larg_Cliente
    }
  
    conditional {
      if ($input.Custo_Borda_ML > 0) {
        var.update $Custo_Mat_Prima {
          value = $Custo_Mat_Prima|add:$input.Custo_Borda_ML
        }
      
        function.run v_cst_m {
          input = {
            Comp       : $Comp
            Larg       : $Larg
            Fator_Comp : $input.FC_Comprimento
            L_fixa     : $input.Larg_Fixa
            Valor_Custo: $Custo_Mat_Prima
          }
        } as $func_1
      }
    }
  
    var $Pers {
      value = ""
    }
  
    var $temp1 {
      value = 0
    }
  
    var $temp2 {
      value = 0
    }
  
    // Caso o valor seja > 0 é uma personalização do produto. Então será calculado de forma diferente.
    conditional {
      if ($input.Custo_Borda_ML > 0) {
        var.update $Pers {
          value = $func_1
        }
      
        var.update $Area_Requerida {
          value = 0
        }
      
        var.update $Comp {
          value = $Pers.comp_fc
        }
      
        var.update $Larg {
          value = $Pers.larg_fc
        }
      }
    
      else {
        var.update $Area_Requerida {
          value = $input.Area_do_Cliente
        }
      
        var.update $Comp {
          value = $input.Comp_Cliente
        }
      
        var.update $Larg {
          value = $input.Larg_Cliente
        }
      }
    }
  
    conditional {
      if ($input.Area_do_Cliente > 0) {
        var.update $Area_Requerida {
          value = $input.Area_do_Cliente
        }
      }
    
      else {
        var.update $Area_Requerida {
          value = $Larg|multiply:$Comp
        }
      
        var.update $temp1 {
          value = $Larg
        }
      
        var.update $temp2 {
          value = $Comp
        }
      }
    }
  
    function.run Marguem_Multiplicadora {
      input = {Marguem: $input.margem}
    } as $margem_Mult
  
    function.run "Comprimento=Area_Div_LarguraFixa" {
      input = {
        Area       : $Area_Requerida
        Larg_Fixa  : $input.Larg_Fixa
        Tam_do_Rolo: $input.Tam_Total_Pca
      }
    } as $Comp_em_Metros
  
    conditional {
      if ($temp1 == 0) {
        var.update $temp1 {
          value = $input.Larg_Fixa
        }
      }
    }
  
    conditional {
      if ($temp2 == 0) {
        var.update $temp2 {
          value = $Comp_em_Metros
        }
      }
    }
  
    !debug.stop {
      value = $Area_Requerida
    }
  
    var $Area_Total {
      value = $Comp_em_Metros|multiply:$input.Larg_Fixa
    }
  
    var $Valor_Custo_Ml {
      value = $Custo_Mat_Prima|multiply:$Comp_em_Metros|round:2
    }
  
    function.run Valor_Venda {
      input = {
        Valor_Custo                 : $Valor_Custo_Ml
        Valor_Marguem_Multiplicadora: $margem_Mult
      }
    } as $Valor_de_Venda
  
    !debug.stop {
      value = $Valor_de_Venda
    }
  
    var $Valor_Lucro {
      value = $Valor_de_Venda|subtract:$Valor_Custo_Ml|round:2
    }
  
    var $Qtd_Rolos {
      value = $Comp_em_Metros
        |divide:$input.Tam_Total_Pca
        |floor
    }
  
    var $Qtd_m {
      value = $Comp_em_Metros
        |subtract:($input.Tam_Total_Pca|multiply:$Qtd_Rolos)
    }
  
    var $Qtd_txt {
      value = "Rolos:"
        |concat:$Qtd_Rolos:" "
        |concat:$Qtd_m:" + "
        |concat:"":"m"
        |concat:$Comp_em_Metros:" ou "
        |concat:"m":""
    }
  
    conditional {
      if ($Valor_Custo_Ml >= 750) {
        var $Valor_Venda_Total_FRT_B2B {
          value = $Valor_de_Venda
        }
      }
    
      else {
        var $Valor_Venda_Total_FRT_B2B {
          value = $Valor_de_Venda|add:$input.Frete_B2B
        }
      }
    }
  
    var $valor_custo_ml {
      value = $Custo_Mat_Prima
    }
  
    var $valor_venda_ml {
      value = $Valor_de_Venda|divide:$Comp_em_Metros
    }
  
    var $valor_lucro_ml {
      value = $Valor_Lucro|divide:$Comp_em_Metros
    }
  
    // Este valor é calculado da seguinte forma:
    // valor_venda_ml + (frete_B2B/int_Qtd)
    var $valor_venda_b2b_ml {
      value = $Valor_Venda_Total_FRT_B2B|divide:$Comp_em_Metros
    }
  
    var $Area_ml {
      value = $Area_Total|divide:$Comp_em_Metros
    }
  
    var $vlr_IPI_unit {
      value = $cst_IPI|multiply:$margem_Mult
    }
  
    var $vlr_IMP_unit {
      value = $cst_IMP|multiply:$margem_Mult
    }
  
    var $vlr_IPI_Total {
      value = $cst_IPI
        |multiply:$margem_Mult
        |multiply:$Comp_em_Metros
    }
  
    var $vlr_IMP_Total {
      value = $cst_IMP
        |multiply:$margem_Mult
        |multiply:$Comp_em_Metros
    }
  
    var $Obs1 {
      value = "O valor_venda_ml já tem incluso o vlr_IPI_unit + vlr_IMP_unit"
    }
  
    var $Obs2 {
      value = "O valor_custo_ml já tem incluso o cst_IPI_unit + cst_IMP_unit"
    }
  }

  response = {
    func_1: ```
      {
        comprimento          : $temp2
        largura              : $temp1
        Area_Total           : $Area_Total
        Larg_Fixa            : $input.Larg_Fixa
        Comp_em_Metros       : $Comp_em_Metros
        Valor_Custo_Unit     : $valor_custo_ml
        Valor_Custo_Total    : $Valor_Custo_Ml
        Valor_Venda_Total    : $Valor_de_Venda
        Valor_Venda_Total_B2B: $Valor_Venda_Total_FRT_B2B
        Valor_Lucro          : $Valor_Lucro
        Valor_Lucro_Total    : $Valor_Lucro
        Qtd_Rolos            : $Qtd_Rolos
        int_Qtd              : $Qtd_m
        Qtd_txt              : $Qtd_txt
        Area_ml              : $Area_ml
        valor_custo_ml       : $valor_custo_ml
        valor_venda_ml       : $valor_venda_ml
        valor_lucro_ml       : $valor_lucro_ml
        valor_venda_b2b_ml   : $valor_venda_b2b_ml
        Det_Personalizado    : $Pers
        cst_IPI              : $cst_IPI
        cst_IMP              : $cst_IMP
        CUSTO_ML             : $CUSTO_METRO_LINEAR
        vlr_IPI_Total        : $vlr_IPI_Total
        vlr_IMP_Total        : $vlr_IMP_Total
        vlr_IPI_unit         : $vlr_IPI_unit
        vlr_IMP_unit         : $vlr_IMP_unit
        Obs1                 : $Obs1
        Obs2                 : $Obs2
        Custo_Borda_ML       : $input.Custo_Borda_ML
        Valor_Venda_Unit     : $valor_venda_ml
        Valor_Lucro_Unit     : $valor_lucro_ml
        Valor_Venda_Unit_B2B : $valor_venda_b2b_ml
        Qtd_Unidades         : $Qtd_m
        margem               : $input.margem
      }
      ```
  }

  guid = "XM8ht5MZcmILKuCkohPYhEYF8FE"
}