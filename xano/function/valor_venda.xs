// Calcul do Valor de Venda = Custo x Marguem
function Valor_Venda {
  input {
    decimal Valor_Custo?
    decimal Valor_Marguem_Multiplicadora?
  }

  stack {
    var $Valor_Venda {
      value = $input.Valor_Custo
        |multiply:$input.Valor_Marguem_Multiplicadora
    }
  }

  response = $Valor_Venda
  guid = "4wT6YhaFxqMT5jwYKItmLBLNKz4"
}