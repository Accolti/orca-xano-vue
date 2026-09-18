// 3. Retorna a resposta limpa e padronizada
function f_valor_custo_kit {
  input {
    decimal comprimento_ou_area?
    decimal largura?
    json produto?
  }

  stack {
    // 1. Precondition para garantir que o produto existe
    precondition (($input.produto|count) > 0) {
      error_type = "notfound"
      error = "Produto não encontrado"
      payload = "produto"
    }
  
    // 2. Executa toda a matemática, lógica de Kit e formatação no Lambda
  
    api.lambda {
      code = """
        // Captura e validação das entradas
        const DEBUG = false;
        const prd = $input.produto && $input.produto.length > 0 ? $input.produto[0] : null;
        const compOuArea = Number($input.comprimento_ou_area) || 0;
        const largInput = Number($input.largura) || 0;
        
        if (!prd) {
          return { error: "notfound", message: "Produto não encontrado" };
        }
        
        // Extração de dados da variação (Dimensões da peça do Kit)
        const variacao = prd._variacao || {};
        const custoKit = Number(variacao.valor_custo) || 0;
        const largKit = Number(variacao.larg) || 0.3; // Módulo de largura (Ex: 0.3)
        const compKit = Number(variacao.comp) || 0.3; // Módulo de comprimento (Ex: 0.3)
        const qtdPecasKit = Number(variacao.qtd_kit) || 1;
        const cstBorda = Number(prd.borda_valor) || 0;
        const ipi = Number(prd.ipi) || 0;
        
        // Área de 1 peça individual do Kit
        const areaPeca = largKit * compKit; 
        
        let largFC = 0;
        let compFC = 0;
        let totalPecasNecessarias = 0;
        
        // 1. ADEQUAÇÃO DAS DIMENSÕES PARA MÚLTIPLOS DAS PEÇAS DO KIT
        if (compOuArea > 0 && largInput > 0) {
          // Arredonda a quantidade de peças necessárias para cima em cada eixo
          const pecasNoComp = Math.ceil(compOuArea / compKit);
          const pecasNaLarg = Math.ceil(largInput / largKit);
        
          // Redimensiona o comprimento e largura da FC para múltiplos exatos do Kit
          compFC = Number((pecasNoComp * compKit).toFixed(2));
          largFC = Number((pecasNaLarg * largKit).toFixed(2));
        
          // Quantidade total de peças cobradas
          totalPecasNecessarias = pecasNoComp * pecasNaLarg;
        
        } else if (compOuArea > 0 && largInput === 0) {
          // Caso o cliente passe apenas a Área Total desejada (m²)
          totalPecasNecessarias = areaPeca > 0 ? Math.ceil(compOuArea / areaPeca) : 0;
          
          // Mantém os campos de dimensão indicando a área ajustada
          compFC = Number((totalPecasNecessarias * areaPeca).toFixed(2));
          largFC = 0;
        }
        
        // 2. CÁLCULO DOS KITS NECESSÁRIOS
        // Quantidade de kits fechados para suprir o total de peças cobradas
        const qtdKits = qtdPecasKit > 0 ? Math.ceil(totalPecasNecessarias / qtdPecasKit) : 0;
        
        // 3. CUSTO E IMPOSTOS
        const materiaPrimaMaisBordaTotal = Number(((custoKit + cstBorda) * qtdKits).toFixed(2));
        const vlrIpiTotal = Number(((materiaPrimaMaisBordaTotal * ipi) / 100).toFixed(2));
        const vlrIpiUnit = qtdKits > 0 ? Number((vlrIpiTotal / qtdKits).toFixed(2)) : 0;
        
        const custoNotaTotal = Number((materiaPrimaMaisBordaTotal + vlrIpiTotal).toFixed(2));
        const custoNotaUnit = qtdKits > 0 ? Number((custoNotaTotal / qtdKits).toFixed(2)) : 0;
        
        // Descrição formatada
        const descricao = [
          prd.material_nome,
          prd.linha_nome,
          prd.tipo_nome,
          prd.nivel_nome,
          prd.borda_nome
        ].filter(Boolean).join(" ");
        
        // 🔍 RETORNO DE DEBUG
        if (DEBUG) {
          return {
            _DEBUG_LOG: "Adequação de Módulos executada com sucesso",
            solicitado: { comprimento: compOuArea, largura: largInput },
            faturado_fc: { comprimento_fc: compFC, largura_fc: largFC },
            total_pecas: totalPecasNecessarias,
            qtd_kits: qtdKits,
            custo_total: custoNotaTotal
          };
        }
        
        // Retorno final padronizado
        return {
          descricao: descricao,
          quantidade: qtdKits,
          largura: largInput,              // Medida informada pelo cliente
          comprimento: compOuArea,         // Medida informada pelo cliente
          largura_fc: largFC,              // Medida faturada (Múltiplo do Kit)
          comprimento_fc: compFC,          // Medida faturada (Múltiplo do Kit)
          ncm: prd.ncm || null,
          fc               : [],
          fator_de_corte_id: 0,
          tipo_fator_id    : 0,
          com_medida_exata      : false,
          acrescimo_medida_exata: 0,
          detalhes_calculo      : null,
          valores: {
            custo_materia_prima: custoKit,
            custo_borda: cstBorda,
            custo_total: materiaPrimaMaisBordaTotal,
            aliquota_ipi: ipi,
            valor_ipi_tot: vlrIpiTotal,
            valor_ipi_unit: vlrIpiUnit,
            custo_nota_tot: custoNotaTotal,
            custo_nota_unit: custoNotaUnit
          }
        };
        """
      timeout = 10
    } as $resultado
  }

  response = $resultado
  guid = "YNfGWKlXhOaSL7Og4b_HXH9HEWw"
}