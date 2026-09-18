// Cálculo do produto composto PLAYKAP (piso modular).
// Venda por M²; composto de Placas (30×30cm), Rampas (macho/fêmea) e Cantoneiras.
// Segue o mesmo contrato de saída das demais f_valor_custo_* ($mod1) para não
// comprometer o orquestrador; os detalhes da composição vão em detalhes_calculo (JSON).
function f_valor_custo_playkap {
  input {
    decimal comprimento_ou_area?
    decimal largura?
  
    // 4 lados do perímetro com rampa (independentes)
    bool rampa_larg1?
  
    bool rampa_comp1?
    bool rampa_larg2?
    bool rampa_comp2?
    int qtd_cantos?
    json produto?
  }

  stack {
    var $prd {
      value = $input.produto|first
    }
  
    precondition (($input.produto|count) > 0) {
      error_type = "notfound"
      error = "Produto não encontrado"
      payload = "produto"
    }
  
    // Busca as variações de componente do detalhe (Placa/Rampa/Cantoneira)
    db.query Variacao {
      join = {
        Tipo_Variacao: {
          table: "Tipo_Variacao"
          type : "left"
          where: $db.Variacao.tipo_variacao_id == $db.Tipo_Variacao.id
        }
      }
    
      where = $db.Variacao.detalhe_id == $prd.detalhe_id
      eval = {tipo_nome: $db.Tipo_Variacao.Descricao}
      return = {type: "list"}
      output = [
        "id"
        "tipo_variacao_id"
        "tipo_nome"
        "comp"
        "larg"
        "qtd_kit"
        "valor_custo"
      ]
    } as $variacoes
  
    api.lambda {
      code = """
        const rampaLarg1 = $input.rampa_larg1 === true;
        const rampaComp1 = $input.rampa_comp1 === true;
        const rampaLarg2 = $input.rampa_larg2 === true;
        const rampaComp2 = $input.rampa_comp2 === true;
        const qtdCantos = Number($input.qtd_cantos) || 0;
        const variacoes = $var.variacoes || [];
        
        const TAMANHO_PLACA = 0.30; // 30cm
        
        // Modo ÁREA: quando a largura é 0, comprimento_ou_area contém a ÁREA total (m²).
        // Adota-se a premissa geométrica de quadrado perfeito (sqrt) para derivar a grade.
        let comp = Number($input.comprimento_ou_area) || 0;
        let larg = Number($input.largura) || 0;
        if (larg <= 0 && comp > 0) {
          const lado = Math.sqrt(comp);
          comp = lado;
          larg = lado;
        }
        
        // Compra mínima vem da variação Placa (campo Qtd Kit); fallback 11 (1m²)
        const getQtdKit = (nome) => {
          const v = variacoes.find(v => (v.tipo_nome || '').toLowerCase().includes(nome.toLowerCase()));
          return v ? Number(v.qtd_kit) || 0 : 0;
        };
        const COMPRA_MINIMA = getQtdKit('placa') || 11;
        
        // Lê o custo de cada componente pelas variações (por nome do Tipo_Variacao)
        const getCusto = (nome) => {
          const v = variacoes.find(v => (v.tipo_nome || '').toLowerCase().includes(nome.toLowerCase()));
          return v ? Number(v.valor_custo) || 0 : 0;
        };
        const custoPlaca = getCusto('placa');
        const custoRampa = getCusto('rampa');
        const custoCantoneira = getCusto('cantoneira');
        
        // 1. PLACAS (múltiplos de 30cm, arredondando para cima)
        const placasComp = comp > 0 ? Math.ceil(comp / TAMANHO_PLACA) : 0;
        const placasLarg = larg > 0 ? Math.ceil(larg / TAMANHO_PLACA) : 0;
        let totalPlacas = Math.max(1, placasComp) * Math.max(1, placasLarg);
        
        const compAjustadoM = Number((Math.max(1, placasComp) * TAMANHO_PLACA).toFixed(2));
        const largAjustadoM = Number((Math.max(1, placasLarg) * TAMANHO_PLACA).toFixed(2));
        const areaRealM2 = Number((compAjustadoM * largAjustadoM).toFixed(2));
        
        // Compra mínima: 1m² = 11 peças
        const compraMinimaAplicada = totalPlacas < COMPRA_MINIMA;
        if (compraMinimaAplicada) totalPlacas = COMPRA_MINIMA;
        
        // 2. RAMPAS — cada aresta do perímetro demanda a quantidade de placas daquela dimensão:
        //    aresta de comprimento = placasComp rampas; aresta de largura = placasLarg rampas.
        //    Divisão macho/fêmea automática (ceil/floor).
        const pc = Math.max(1, placasComp);
        const pl = Math.max(1, placasLarg);
        const totalRampas = (rampaLarg1 ? pl : 0)
                         + (rampaComp1 ? pc : 0)
                         + (rampaLarg2 ? pl : 0)
                         + (rampaComp2 ? pc : 0);
        
        const rampasMacho = Math.ceil(totalRampas / 2);
        const rampasFemea = Math.floor(totalRampas / 2);
        
        // 3. CANTONEIRAS
        const totalCantoneiras = Math.min(4, Math.max(0, qtdCantos));
        
        // 4. CUSTO DO CONJUNTO (sem impostos — markup/Precificar no orquestrador)
        const custoPlacas = Number((totalPlacas * custoPlaca).toFixed(2));
        const custoRampas = Number((totalRampas * custoRampa).toFixed(2));
        const custoCantoneiras = Number((totalCantoneiras * custoCantoneira).toFixed(2));
        const custoTotal = Number((custoPlacas + custoRampas + custoCantoneiras).toFixed(2));
        
        const descricao = 'PLAYKAP';
        const ncm = $var.prd?.ncm || null;
        const ipi = Number($var.prd?.ipi) || 0;
        const vlrIpi = Number((custoTotal * ipi / 100).toFixed(2));
        const custoNota = Number((custoTotal + vlrIpi).toFixed(2));
        
        // Quantidade do item = total de peças do conjunto (placas + rampas + cantoneiras),
        // mais fiel ao que será entregue. Unitários derivados = total ÷ totalPecas.
        const totalPecas = totalPlacas + totalRampas + totalCantoneiras;
        
        return {
          descricao: descricao,
          quantidade: totalPecas,
          largura: Number(larg.toFixed(2)),
          comprimento: Number(comp.toFixed(2)),
          largura_fc: largAjustadoM,
          comprimento_fc: compAjustadoM,
          ncm: ncm,
          fc: [],
          fator_de_corte_id: 0,
          tipo_fator_id: 0,
          com_medida_exata: false,
          acrescimo_medida_exata: 0,
          valores: {
            custo_materia_prima: custoTotal,
            custo_borda: 0,
            custo_total: custoTotal,
            aliquota_ipi: ipi,
            valor_ipi_tot: vlrIpi,
            valor_ipi_unit: totalPecas > 0 ? Number((vlrIpi / totalPecas).toFixed(2)) : 0,
            custo_nota_tot: custoNota,
            custo_nota_unit: totalPecas > 0 ? Number((custoNota / totalPecas).toFixed(2)) : 0
          },
          detalhes_calculo: {
            playkap: {
              placas: totalPlacas,
              rampas_total: totalRampas,
              rampas_macho: rampasMacho,
              rampas_femea: rampasFemea,
              cantoneiras: totalCantoneiras,
              lados: {
                rampa_larg1: rampaLarg1,
                rampa_comp1: rampaComp1,
                rampa_larg2: rampaLarg2,
                rampa_comp2: rampaComp2
              },
              area_m2: areaRealM2,
              compra_minima_aplicada: compraMinimaAplicada,
              custos: {
                placas: custoPlacas,
                rampas: custoRampas,
                cantoneiras: custoCantoneiras
              }
            }
          }
        };
        """
      timeout = 10
    } as $resultado
  }

  response = $resultado
  guid = "OrcaKap-f-valor-custo-playkap"
}