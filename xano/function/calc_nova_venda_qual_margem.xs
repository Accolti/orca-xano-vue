// Recalcula a margem para que o orçamento atinja o Valor de Venda desejado.
// O frete B2B é calculado automaticamente pela regra Kapazi (fCalculaFrete),
// independente do valor informado no input.
function Calc_Nova_Venda_qual_Margem {
  input {
    decimal Valor_Venda?
    decimal Valor_Custo?
    decimal valor_frete_b2b?
  }

  stack {
    var $valor_cst_total {
      value = $input.Valor_Custo
    }
  
    var $new_valor_venda_total {
      value = $input.Valor_Venda
    }
  
    // Frete B2B Kapazi sobre o custo total (>=1000 → 0, >=300 → 10%, <300 → 52)
    function.run fCalculaFrete {
      input = {
        valor_total_compra: $input.Valor_Custo
        user_id           : $auth.id
      }
    } as $frete_calculado
  
    var.update $new_valor_venda_total {
      value = $new_valor_venda_total|subtract:$frete_calculado
    }
  
    var $Marguem {
      value = $new_valor_venda_total
        |divide:$input.Valor_Custo
        |subtract:1
        |multiply:100
        |!round:4
    }
  }

  response = $Marguem
  guid = "eqZD1M2tBo0j6qbwfR99RIXVMF0"
}