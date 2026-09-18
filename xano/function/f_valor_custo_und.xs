// 4. Retorna diretamente a saída processada pelo Lambda
function f_valor_custo_und {
  input {
    decimal quantidade?
    json[] prd?
  }

  stack {
    // 1. Garante que o produto existe
    precondition (($input.prd|count) > 0) {
      error_type = "notfound"
      error = "Produto não encontrado"
      payload = "produto:"|concat:$input.nome_produto:""
    }
  
    // 2. Garante que a base de cálculo é UND
    precondition ((($input.prd|first) Base_de_Calculo|to_upper) == "UND") {
      error_type = "notfound"
      error = "Esta função não aceita base diferente de UND"
      payload = "Base de Calculo"
        |concat:($input.prd|first).Base_de_Calculo:""
    }
  
    // 3. Executa a lógica central no Lambda
  
    api.lambda {
      code = """
        // Captura das entradas
        const prd = $input.prd ? $input.prd[0] : null;
        const qtd = Number($input.quantidade) || 0;
        
        if (!prd) {
          return { error: "notfound", message: "Produto não encontrado" };
        }
        
        // Extração e fallback de valores
        const cst_materia_prima = Number(prd._variacao?.valor_custo) || 0;
        const cst_borda = Number(prd.borda_valor) || 0;
        const aliquota_ipi = Number(prd.ipi) || 0;
        
        // Cálculos com arredondamento de 2 casas decimais
        const materia_prima_mais_borda_total = Number(((cst_materia_prima + cst_borda) * qtd).toFixed(2));
        const vlr_ipi_total = Number(((materia_prima_mais_borda_total * aliquota_ipi) / 100).toFixed(2));
        const custo_nota_total = Number((materia_prima_mais_borda_total + vlr_ipi_total).toFixed(2));
        
        // Cálculo dos valores unitários (evita divisão por zero)
        const vlr_ipi_unit = qtd > 0 ? Number((vlr_ipi_total / qtd).toFixed(2)) : 0;
        const custo_nota_unit = qtd > 0 ? Number((custo_nota_total / qtd).toFixed(2)) : 0;
        
        // Descrição formatada (filtra nulos/vazios e junta com espaço)
        const descricao = [
          prd.material_nome,
          prd.linha_nome,
          prd.tipo_nome,
          prd.nivel_nome,
          prd.borda_nome
        ].filter(Boolean).join(" ");
        
        // Retorno exatamente no mesmo formato da sua resposta original
        return {
          descricao: descricao,
          quantidade: qtd,
          largura: prd._variacao?.larg || null,
          comprimento: prd._variacao?.comp || null,
          largura_fc: prd._variacao?.larg || null,
          comprimento_fc: prd._variacao?.comp || null,
          ncm: prd.ncm || null,
          fc               : [],
          fator_de_corte_id: 0,
          tipo_fator_id    : 0,
          com_medida_exata      : false,
          acrescimo_medida_exata: 0,
          detalhes_calculo      : null,
          valores: {
            custo_materia_prima: cst_materia_prima,
            custo_borda: cst_borda,
            custo_total: materia_prima_mais_borda_total,
            "aliquota_ipi": aliquota_ipi,
            valor_ipi_tot: vlr_ipi_total,
            valor_ipi_unit: vlr_ipi_unit,
            custo_nota_tot: custo_nota_total,
            "custo_nota_unit": custo_nota_unit
          }
        };
        """
      timeout = 10
    } as $retorno
  }

  response = $retorno
  guid = "Myt2W_-_GSaablAsznzJeGu5Pr4"
}