function calcular_precificacao {
  input {
    text uf_origem? filters=trim
    text uf_destino? filters=trim
    decimal valor_nota?
    decimal frete?
    text regime_empresa? filters=trim
    bool eh_importado?
    decimal markup?
  }

  stack {
    // 1. Busca os dados do estado de DESTINO no banco
    db.get Aliquotas_icms {
      field_name = "uf"
      field_value = $input.uf_destino
    } as $estado_destino
  
    // 2. Busca os dados do estado de ORIGEM no banco
    db.get Aliquotas_icms {
      field_name = "uf"
      field_value = $input.uf_origem
    } as $estado_origem
  
    // 3. Executa a lógica toda no Lambda JavaScript
    api.lambda {
      code = """
        const custoNota = Number($input.custo_nota) || Number($input.valor_nota) || 0; // Custo com IPI
          const frete = Number($input.frete) || 0;
          const isImportado = Boolean($input.eh_importado);
          const regime = ($input.regime_empresa || '').toUpperCase();
          const markup = Number($input.markup) || 100;
        
          const ufOrigem = ($input.uf_origem || '').toUpperCase();
          const ufDestino = ($input.uf_destino || '').toUpperCase();
        
          const destAliquota = Number($var.estado_destino?.aliquota_modal) || 18;
          const origRegiao = $var.estado_origem?.regiao || 'OUTROS';
          const destRegiao = $var.estado_destino?.regiao || 'OUTROS';
        
          // 1. Alíquota Interestadual de Entrada
          let aliqInter = 12;
          if (isImportado) {
            aliqInter = 4;
          } else if (origRegiao === 'SUL_SUDESTE' && destRegiao === 'OUTROS') {
            aliqInter = 7;
          }
        
          // 2. Apuração por Regime Tributário
          let percDifal = 0;
          let valDifal = 0;
          let creditoIcms = 0;
          let custoReal = custoNota + frete;
        
          const isSimplesOuMei = (regime === 'MEI' || regime === 'SIMPLES' || regime === 'SIMPLES_NACIONAL');
        
          if (isSimplesOuMei) {
            // Para MEI/Simples: Paga DIFAL (se for interestadual) e NÃO tem crédito
            if (ufOrigem !== ufDestino) {
              percDifal = Math.max(0, destAliquota - aliqInter);
              valDifal = custoNota * (percDifal / 100);
            }
            custoReal += valDifal; // Custo = Nota + Frete + DIFAL
        
          } else {
            // Para Lucro Presumido / Lucro Real: NÃO paga DIFAL na compra para revenda
            // E ganha CRÉDITO do ICMS Interestadual
            percDifal = 0;
            valDifal = 0;
            creditoIcms = custoNota * (aliqInter / 100);
            
            custoReal = (custoNota + frete) - creditoIcms; // Custo Líquido
          }
        
          // 3. Preço e Lucro Estimados
          const lucroEstimado = custoReal * (markup / 100);
          const precoVendaEstimado = custoReal + lucroEstimado;
        
          return {
            uf_origem: ufOrigem,
            uf_destino: ufDestino,
            regime: regime,
            aliquota_interestadual: aliqInter + "%",
            aliquota_interna_destino: destAliquota + "%",
            percentual_difal: percDifal + "%",
            valor_difal: Number(valDifal.toFixed(2)),             // Será 0 para Presumido/Real
            credito_icms_entrada: Number(creditoIcms.toFixed(2)), // Ativo para Presumido/Real
            custo_real: Number(custoReal.toFixed(2)),
            lucro_reais: Number(lucroEstimado.toFixed(2)),
            preco_venda: Number(precoVendaEstimado.toFixed(2))
          };
        """
      timeout = 10
    } as $x1
  }

  response = $x1
  guid = "G8ovtM8ED7-hAMGeh_wYR3294Go"
}