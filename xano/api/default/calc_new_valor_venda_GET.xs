// recalcula a margem para um novo valor de venda 
query Calc_new_Valor_Venda verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    // Novo valor de venda pretendido
    decimal new_val_venda_total?
  
    // Valor do custo do material
    decimal valor_custo_total?
  
    decimal valor_frete_b2b?
  }

  stack {
    function.run Calc_Nova_Venda_qual_Margem {
      input = {
        Valor_Venda    : $input.new_val_venda_total
        Valor_Custo    : $input.valor_custo_total
        valor_frete_b2b: $input.valor_frete_b2b
      }
    } as $New_Marguem
  }

  response = {new_margem: $New_Marguem}
  guid = "BlVPXo0TlPlYqTVnsFNFXsp2-Ko"
}