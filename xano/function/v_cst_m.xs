// Vai calcular o valor de custo.
// v_cst_m = (comp_fc*valor_custo_ML)*(larg_fc /L_fixa)
// o comp_fc vai ser calc com a função  FCMultiplo e o larg_fc tb.
function v_cst_m {
  input {
    decimal Comp?
    decimal Larg?
    int Fator_Comp?
    decimal L_fixa?
    decimal Valor_Custo?
  }

  stack {
    // 1. Calcula o comprimento faturado
    function.run FCMultiplo {
      input = {Numero: $input.Comp, valorDoMultiplo: $input.Fator_Comp}
    } as $res_comp
  
    var $comp_fc {
      value = $res_comp.Valor
    }
  
    // 2. Calcula a largura faturada
    function.run FCMultiplo {
      input = {Numero: $input.Larg, valorDoMultiplo: $input.L_fixa}
    } as $res_larg
  
    var $larg_fc {
      value = $res_larg.Valor
    }
  
    // 3. Calcula a quantidade de cortes/vezes que a largura fixa é usada
    var $qtd_cortes {
      value = $larg_fc|divide:$input.L_fixa
    }
  
    var $val_cst_m {
      value = $input.Valor_Custo
    }
  
    // 4. Custo total baseado no comprimento faturado e na quantidade de larguras gastas
    var $val_cst_m_tot {
      value = $comp_fc
        |multiply:$input.Valor_Custo
        |multiply:$qtd_cortes
    }
  
    // 5. Montagem do texto de cobrança corrigido
    var $cobrado {
      value = $input.L_fixa
        |concat:" x "
        |concat:$comp_fc
        |concat:" -> peças: "
        |concat:$qtd_cortes
    }
  }

  response = {
    val_cst_m            : $val_cst_m
    qtd_cortes           : $qtd_cortes
    comp_fc              : $comp_fc
    larg_fc              : $larg_fc
    "cobrado_(LargXComp)": $cobrado
    val_cst_m_tot        : $val_cst_m_tot
  }

  guid = "FvEFdTjsPAJo0MTnf2Km39kcI8w"
}