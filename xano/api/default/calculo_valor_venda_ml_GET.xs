// A descrição desta API está na função chamada abaixo
query CalculoValorVenda_ML verb=GET {
  api_group = "Default"

  input {
    decimal Area_do_Cliente
    decimal Largura?
    decimal Comprimento?
  
    // É a largurua fixa. Exemplo no rubberkap é 1m, no laminado pode ser 1.3 ou 2 m , no laminado 1. Grama sintetica 2m . Essa informação esta na tabela  Fator_de_Corte
    decimal Largura_Fixa?
  
    decimal Tamanho_Total_Peca?
    decimal Custo_MP_Geral?
    decimal Margem?=100
    decimal Frete_B2B?
    decimal Custo_Borda_ML?
  
    // FC do Comprimento exemplo para o rubberkap ele é vendido de um em um metro. Grama sintética também e laminados. Esta informação é armazenada na tabela Fator_de_Corte
    decimal fc_Comprimento?
  
    decimal IMP?
    decimal IPI?
    text Base_Calc_MP? filters=trim
  }

  stack {
    function.run Valor_Venda_ML {
      input = {
        Area_do_Cliente: $input.Area_do_Cliente
        Larg_Cliente   : $input.Largura
        Comp_Cliente   : $input.Comprimento
        Larg_Fixa      : $input.Largura_Fixa
        Tam_Total_Pca  : $input.Tamanho_Total_Peca
        Custo_MP_Geral : $input.Custo_MP_Geral
        margem         : $input.Margem
        Frete_B2B      : $input.Frete_B2B
        Custo_Borda_ML : $input.Custo_Borda_ML
        FC_Comprimento : $input.fc_Comprimento
        IMP            : $input.IMP
        IPI            : $input.IPI
        Base_Calc_MP   : $input.Base_Calc_MP
      }
    } as $func_1
  }

  response = $func_1
  guid = "mrDI8TuynMm7IaKq7mgLIO3zdEU"
}