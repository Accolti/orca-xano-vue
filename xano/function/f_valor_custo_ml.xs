function f_valor_custo_ml {
  input {
    // Comprimento (em metros) OU a Área Total (em m²) se a largura for null/0
    decimal comprimento_ou_area?
  
    // Se esta informado area no campo comprimento_ou_area este campo precisa receber 0 ou nulo
    decimal largura?
  
    json produto?
  
    // Vendedor marcou medida exata → aplica porcentagem_acrescimo do produto no custo
    bool com_medida_exata?
  }

  stack {
    var $prd {
      value = $input.produto|first
    }
  
    var $variacao {
      value = $prd._variacao
    }
  
    var $fc {
      value = $variacao._fator_de_corte_variacao|first
    }
  
    var $larg_fixa {
      value = $fc.larg_base
    }
  
    var $tam_rolo {
      value = $fc.tam_total
    }
  
    var $valor_custo {
      value = $variacao.valor_custo
    }
  
    var $tipo_preco {
      value = $prd.Unidade
    }
  
    var $fator_corte {
      value = $fc.comp_corte
    }
  
    var $aliq_ipi {
      value = $prd.ipi
    }
  
    var $unidade_borda {
      value = $prd.borda_unidade
    }
  
    var $valor_borda {
      value = $prd.borda_valor
    }
  
    api.lambda {
      code = """
        
        /**
         * ==================================================================================
         * SISTEMA DINÂMICO DE PAGINAÇÃO E ORÇAMENTO DE PRODUTOS EM ML (GERALMENTE P/ ROLO)
         * grama, piso laminado , h-kap- skap etc... 	
         * ==================================================================================
         * * COMO FUNCIONA A LÓGICA INTERNA:
         * 1. Identificação do Modo: Se a largura for informada, faz a paginação inteligente 
         * (testando os dois sentidos). Se a largura for 0 ou nula, calcula por Área Líquida.
         * 2. Conversão de Preço: O script verifica se o preço foi informado em M². Se sim, 
         * ele multiplica o valor pela largura fixa do rolo para descobrir o preço por 
         * metro linear (mL).
         * 3. Divisão por Rolos: Com base no tamanho total do rolo do fornecedor, calcula
         * quantos rolos fechados serão necessários e a fração exata que sobra.
         * ----------------------------------------------------------------------------------
         * PARÂMETROS QUE DEVEM SER INFORMADOS (ENTRADAS):
         * @param {number} comprimentoOrArea - Comprimento (em metros) OU a Área Total (em m²) se a largura for null/0.
         * @param {number|null} largura      - A largura total (em metros). Use null ou 0 para cálculo direto por Área.
         * @param {number} larg_fixa         - A largura fixa do rolo do fornecedor (ex: 1.2 ou 2).
         * @param {number} tam_rolo          - O comprimento total de um rolo fechado (ex: 15 ou 25).
         * @param {number} preco             - O valor numérico do preço (ex: 24.90 ou 92.00).
         * @param {string} tipo_preco        - 'm2' para Metro Quadrado ou 'ml' para Metro Linear.
         * @param {number} fator_corte       - O bloco mínimo de venda/corte da loja (ex: 2.5).
         * ----------------------------------------------------------------------------------
         */
        
        
        let comprimentoOrArea = $input.comprimento_ou_area;
        let largura = $input.largura; 
        let larg_fixa = $var.larg_fixa;
        let tam_rolo = $var.tam_rolo; 
        let preco = $var.valor_custo; 
        let tipo_preco = $var.tipo_preco; 
        let fator_corte = $var.fator_corte;
        let aliquota_ipi = $var.aliq_ipi||0;
        let unidade_borda = $var.unidade_borda || "";
        let custo_borda = $var.valor_borda || 0;
        
        return calcularValordeCustodoProdutoDinamico(comprimentoOrArea, largura, larg_fixa, tam_rolo, preco, tipo_preco, fator_corte, aliquota_ipi, unidade_borda, custo_borda); 
        
        
        function calcularValordeCustodoProdutoDinamico(comprimentoOrArea, largura, larg_fixa, tam_rolo, preco, tipo_preco, fator_corte, aliquota_ipi, unidade_borda, custo_borda) {
            
            // 1. CONVERSÃO DINÂMICA DE PREÇO (M² para Metro Linear se necessário)
            let valor_ml = 0;
            let cst_borda_total = 0;
            if (tipo_preco?.toLowerCase() === 'm2' || tipo_preco?.toLowerCase() === 'm²') {
                valor_ml = preco * larg_fixa;
            } else {
                valor_ml = preco; 
            }
        
            if (unidade_borda?.toLowerCase() === 'ml' ) {
                valor_ml = valor_ml + custo_borda;
            } 
        
            // Medida exata (marcada pelo vendedor): aplica porcentagem_acrescimo do produto no custo por ML
            const medidaExata = $input.com_medida_exata === true && $var.prd?.com_medida_exata === true;
            if (medidaExata) {
                const perc = Number($var.prd?.porcentagem_acrescimo) || 0;
                valor_ml = valor_ml * (1 + perc/100);
            }
        
            let totalMlNecessario = 0;
            let orientacao = "";
        
            // VERIFICAÇÃO: O usuário entrou com Área Bruta ou com as Dimensões?
            if (!largura || largura === 0) {
                // === MODO ÁREA LÍQUIDA ===
                const areaTotal = comprimentoOrArea;
                
                // Metros lineares brutos necessários para cobrir a área baseados na largura do rolo
                const mlBruto = areaTotal / larg_fixa;
                
                // Aplica o fator de corte no resultado linear do rendimento
                totalMlNecessario = Math.ceil(mlBruto / fator_corte) * fator_corte;
                orientacao = `Cálculo baseado em área total líquida (${areaTotal} m²) - Sem paginação`;
        
            } else {
                // === MODO PAGINAÇÃO INTELIGENTE (Seu código original) ===
                const comprimento = comprimentoOrArea;
        
                // CÁLCULO DA OPÇÃO 1: Faixas no sentido do COMPRIMENTO
                const faixas1 = Math.ceil(largura / larg_fixa);
                const compFaixa1 = Math.ceil(comprimento / fator_corte) * fator_corte;
                const totalMl1 = faixas1 * compFaixa1;
        
                // CÁLCULO DA OPÇÃO 2: Faixas no sentido da LARGURA
                const faixas2 = Math.ceil(comprimento / larg_fixa);
                const compFaixa2 = Math.ceil(largura / fator_corte) * fator_corte;
                const totalMl2 = faixas2 * compFaixa2;
        
                // COMPARATIVO DE CUSTO-BENEFÍCIO
                if (totalMl1 <= totalMl2) {
                    totalMlNecessario = totalMl1;
                    orientacao = `Passar a faixa no sentido do comprimento (${comprimento} m)`;
                } else {
                    totalMlNecessario = totalMl2;
                    orientacao = `Passar a faixa no sentido da largura (${largura} m)`;
                }
        
                // Garante que o acumulado final respeite o fator de corte da loja
                totalMlNecessario = Math.ceil(totalMlNecessario / fator_corte) * fator_corte;
            }
        
            // 5. CÁLCULO DE ROLOS FECHADOS E METROS FRACIONADOS (Comum para ambos os modos)
            const rolosInteiros = Math.floor(totalMlNecessario / tam_rolo);
            const mlRestante = totalMlNecessario % tam_rolo;
            const custoTotal = totalMlNecessario * valor_ml;
            let custo_nota = custoTotal;
            const vlr_ipi = custo_nota*(aliquota_ipi/100);
            custo_nota = custo_nota+vlr_ipi;
            cst_borda_total = totalMlNecessario*custo_borda
            // 6. RETORNO DOS DADOS FORMATADOS
            return {
                custoBordaTotalIncluso: cst_borda_total,
                orientacaoIdeal: orientacao,
                totalMetrosLineares: totalMlNecessario,
                valor_ml: valor_ml,
                rolosFechados: rolosInteiros,
                metrosFracionados: mlRestante,
                custoTotal: custoTotal,
                vlr_ipi: vlr_ipi,
                custo_nota: custo_nota,
                resumoTexto: `${rolosInteiros} rolo(s) e ${mlRestante}m do produto. Valor total: R$ ${custo_nota.toFixed(2)}`
            };
        }
        """
      timeout = 10
    } as $retorno
  
    var $unidade_da_materia_prima {
      value = $prd.Unidade|to_upper
    }
  
    var $base_de_calculo {
      value = $prd.Base_de_Calculo|to_upper
    }
  
    var $cst_materia_prima {
      value = $prd.valor
    }
  
    var $cst_borda {
      value = $prd.borda_valor
    }
  
    var $aliquota_imp {
      value = $prd.imp
    }
  
    var $aliquota_ipi {
      value = $prd.ipi
    }
  
    var $descricao {
      value = []
        |push:$prd.material_nome
        |push:$prd.linha_nome
        |push:$prd.tipo_nome
        |push:$prd.nivel_nome
        |push:$prd.borda_nome
    }
  
    function.run f_transformaArrayemString {
      input = {Array: $descricao}
    } as $descricao
  
    var $ncm {
      value = $prd.ncm
    }
  
    var $comprimeto_fc {
      value = $retorno.totalMetrosLineares
    }
  
    var $largura_fc {
      value = $larg_fixa
    }
  
    var $area_total_fc {
      value = $retorno.totalMetrosLineares|multiply:$larg_fixa
    }
  
    var $quantidade {
      value = $retorno.totalMetrosLineares
    }
  
    !var $materia_prima_mais_borda {
      value = $cst_materia_prima|add:$cst_borda
    }
  
    var $custo_total {
      value = $retorno.custoTotal
    }
  
    var $vlr_ipi {
      value = $retorno.vlr_ipi
    }
  
    var $custo_nota {
      value = $retorno.custo_nota|round:2
    }
  
    var $acrescimo_medida_exata {
      value = 0
    }
  
    conditional {
      if ($input.com_medida_exata && $prd.com_medida_exata) {
        var.update $acrescimo_medida_exata {
          value = $prd.porcentagem_acrescimo
        }
      }
    }
  
    // Detalhes de cálculo ML (rolos/metros/orientação) — persistidos como JSON no item,
    // análogo ao detalhes_calculo.playkap dos produtos compostos.
  
    var $detalhes_calculo {
      value = {
        ml: {
          totalMetrosLineares: $retorno.totalMetrosLineares
          rolosFechados       : $retorno.rolosFechados
          metrosFracionados   : $retorno.metrosFracionados
          orientacaoIdeal     : $retorno.orientacaoIdeal
          valor_ml            : $retorno.valor_ml
          custoBordaTotalIncluso: $retorno.custoBordaTotalIncluso
          largura_fixa        : $larg_fixa
          tam_rolo            : $tam_rolo
          fator_corte         : $fator_corte
          resumoTexto         : $retorno.resumoTexto
        }
      }
    }
  
    var $valores {
      value = {}
        |set:"unidade_custo":$prd.Unidade
        |set:"custo_materia_prima":$variacao.valor_custo
        |set:"[base_de_calculo]":$base_de_calculo
        |set:"custo_borda":$cst_borda
        |set:"custo_total":$custo_total
        |set:"[aliquota_ipi]":$aliquota_ipi
        |set:"valor_ipi_tot":$vlr_ipi
        |set:"valor_ipi_unit":($vlr_ipi|divide:$quantidade)
        |set:"custo_nota_tot":$custo_nota
        |set:"custo_nota_unit":($custo_nota|divide:$quantidade)
    }
  }

  response = {
    descricao             : $descricao
    quantidade            : $quantidade
    largura               : $input.largura
    comprimento           : $input.comprimento_ou_area
    largura_fc            : $largura_fc
    comprimento_fc        : $comprimeto_fc
    fc                    : []
    fator_de_corte_id     : 0
    tipo_fator_id         : 0
    ncm                   : $ncm
    valores               : $valores
    retorno               : $retorno
    com_medida_exata      : ($input.com_medida_exata == true) && ($prd.com_medida_exata == true)
    acrescimo_medida_exata: $acrescimo_medida_exata
    detalhes_calculo      : $detalhes_calculo
  }

  guid = "yM3am-zS_Y27OqurnrriHVcl0t4"
}