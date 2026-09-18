// Recalcula a nova margem pelo valor de lucro informado. Qual é o lucro que vc deseja receber?
function Calc_Novo_Lucro_qual_Marguem {
  input {
    decimal Valor_Lucro?
    decimal Valor_Custo?
  }

  stack {
    var $Margem {
      value = $input.Valor_Lucro
        |add:$input.Valor_Custo
        |divide:$input.Valor_Custo
        |subtract:1
        |multiply:100
    }
  }

  response = $Margem
  guid = "CjQDI6BLRWqfqbnDWUB7BOzoZns"
}