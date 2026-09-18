query CalculoValorVenda_Kit verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    decimal Area_FC?
    decimal Larg_FC?
    decimal Comp_FC?
    decimal CustoKit?
    decimal Margem?
    decimal Frete_B2B?
    decimal larg_kit?
    decimal comp_kit?
    int qtd_de_pecas_do_kit?
    decimal IPI?
    decimal IMP?
  }

  stack {
    function.run Valor_Venda_Kit {
      input = {
        Area_FC            : $input.Area_FC
        Larg_FC            : $input.Larg_FC
        Comp_FC            : $input.Comp_FC
        CustoKit           : $input.CustoKit
        Margem             : $input.Margem
        Frete_B2B          : $input.Frete_B2B
        larg_kit           : $input.larg_kit
        comp_kit           : $input.comp_kit
        qtd_de_pecas_do_kit: $input.qtd_de_pecas_do_kit
        IPI                : $input.IPI
        IMP                : $input.IMP
      }
    } as $func_1
  }

  response = {func_1: $func_1}
  guid = "htvqLXnIIal097ogvD8FurhITBA"
}