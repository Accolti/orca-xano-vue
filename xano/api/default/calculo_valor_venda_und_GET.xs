query CalculoValorVenda_UND verb=GET {
  api_group = "Default"

  input {
    decimal Custo_Unidade?
    decimal Margem?
    decimal Frete_B2B?
    int Qtd_Unidades?
    decimal IPI?
    decimal IMP?
    bool bSimular?
  }

  stack {
    function.run Valor_Venda_Unidade {
      input = {
        Custo_Unidade: $input.Custo_Unidade
        Margem       : $input.Margem
        Frete_B2B    : $input.Frete_B2B
        Qtd_Unidades : $input.Qtd_Unidades
        IPI          : $input.IPI
        IMP          : $input.IMP
        Medida       : ""
      }
    } as $func_1
  
    var $cotacoes {
      value = []
    }
  
    conditional {
      if ($input.bSimular) {
        var $margem {
          value = []
            |push:50
            |push:60
            |push:70
            |push:80
            |push:90
            |push:100
        }
      
        foreach ($margem) {
          each as $mar {
            function.run Valor_Venda_Unidade {
              input = {
                Custo_Unidade: $input.Custo_Unidade
                Margem       : $mar
                Frete_B2B    : $input.Frete_B2B
                Qtd_Unidades : $input.Qtd_Unidades
                IPI          : $input.IPI
                IMP          : $input.IMP
                Medida       : ""
              }
            } as $result_val
          
            var.update $cotacoes {
              value = $cotacoes|append:$result_val:""
            }
          
            !debug.stop {
              value = $cotacoes
            }
          }
        }
      }
    }
  }

  response = {func_1: $func_1, simulacao: $cotacoes}
  guid = "J2LxnuJAf-T5ZagPatv_IOSLwhM"
}