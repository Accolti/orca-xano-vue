// Valor de Venda do KII
function Valor_Custo_Kit {
  input {
    // Area calculada pelo FC
    decimal Area_FC?
  
    // Largura: informar a largura já com o fator de corte
    decimal Larg_FC?
  
    // Comprimento inf pelo cliente para calc da área
    decimal Comp_FC?
  
    decimal CustoKit?
  
    // Não entrar com valor em procentage. Enttrar como exemplo 80.55 
    decimal Margem?
  
    decimal Frete_B2B?
    decimal larg_kit
    decimal comp_kit
  
    // De quantas peças o kit é formado
    int qtd_de_pecas_do_kit?
  
    decimal IPI?
    decimal IMP?
  }

  stack {
    !function.run Calc_QtdKits {
      input = {
        Area_Cliente    : $input.Area_FC
        Larg_Kit        : $input.larg_kit
        Comp_Kit        : $input.comp_kit
        Qtd_de_Pecas_Kit: $input.qtd_de_pecas_do_kit
      }
    } as $CustoKit
  
    api.lambda {
      code = """
        // 1. Converter strings para número (previne erros quando os inputs vêm entre aspas no JSON)
        const areaFC = parseFloat($input.Area_FC) || 0;
        const largFC = parseFloat($input.Larg_FC) || 0;
        const compFC = parseFloat($input.Comp_FC) || 0;
        const custoKit = parseFloat($input.CustoKit) || 0;
        const largKit = parseFloat($input.larg_kit) || 0;
        const compKit = parseFloat($input.comp_kit) || 0;
        const qtdPecasKit = parseInt($input.qtd_de_pecas_do_kit) || 1;
        const ipi = parseFloat($input.IPI) || 0;
        const imp = parseFloat($input.IMP) || 0;
        
        // 2. Determinar a Área Requerida
        const areaRequerida = (areaFC > 0) ? areaFC : (largFC * compFC);
        
        // 3. Calcular a Área Total de 1 Kit (Área da peça × quantidade de peças)
        const areaPeca = largKit * compKit;
        const areaKit = areaPeca * qtdPecasKit;
        
        // 4. Quantidade de Kits necessários (arredondado para cima)
        const qtdKits = areaKit > 0 ? Math.ceil(areaRequerida / areaKit) : 0;
        
        // 5. Custo Unitário do Kit com impostos
        const valorCstIpiUnit = custoKit * (ipi / 100);
        const valorCstImpUnit = custoKit * (imp / 100);
        const valorCustoUnitarioFinal = custoKit + valorCstIpiUnit + valorCstImpUnit;
        
        // 6. Custo Total
        const valorCustoTotal = valorCustoUnitarioFinal * qtdKits;
        
        return valorCustoTotal; // Retornará exatamente 600
        """
      timeout = 10
    } as $valor_custo
  }

  response = $valor_custo
  guid = "uYRFf5-ra9Df5Rbyw9hJYotfKpg"
}