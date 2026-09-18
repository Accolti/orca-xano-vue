// recalcula a margem para um novo valor de venda 
query Calc_new_Valor_Lucro verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    // Novo valor de venda pretendido
    decimal new_val_lucro?
  
    // Valor do custo do material
    decimal valor_de_custo?
  }

  stack {
    function.run Calc_Novo_Lucro_qual_Marguem {
      input = {
        Valor_Lucro: $input.new_val_lucro
        Valor_Custo: $input.valor_de_custo
      }
    } as $New_Marguem
  }

  response = {new_margem: $New_Marguem}
  guid = "tY3eeEqQqD3142zeysmfQeJIyqQ"
}