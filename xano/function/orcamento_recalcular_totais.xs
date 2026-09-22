// Recálculo dinâmico do orçamento por somatório.
// Lê todos os itens do orçamento, soma os custos_nota, recalcula o frete B2B (Kapazi)
// sobre o total, rateia proporcionalmente, aplica o markup (efetivo quando newMargem
// informado), desconto e frete B2C, e atualiza itens + cabeçalho ORCA.
function Orcamento_Recalcular_Totais {
  input {
    int orca_id? {
      table = "Orca"
    }
  
    // Markup EFETIVO desejado (%). Se omitido, mantém a margem de cada item
    decimal newMargem?
  
    // frtB2B efetivo já resolvido pelo caller (opcional) — evita reconsultar User/Perfil
    decimal frt_b2b?
    bool frt_b2b_informado?
  }

  stack {
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
    } as $Orca_0
  
    // Trava: pedido convertido (eh_pedido == true) é read-only — não recalcula.
  
    var $pedidoBloqueado {
      value = false
    }
  
    conditional {
      if ($Orca_0 != null) {
        var.update $pedidoBloqueado {
          value = ($Orca_0.eh_pedido == true)
        }
      }
    }
  
    precondition ($pedidoBloqueado != true) {
      error_type = "badrequest"
      error = "Orçamento convertido em pedido. Recálculo bloqueado."
    }
  
    db.query item {
      join = {
        Produto : {
          table: "Produto"
          where: $db.item.produto_id == $db.Produto.id
        }
        Material: {
          table: "Material"
          where: $db.Material.id == $db.Produto.material_id
        }
        Linha   : {
          table: "Linha"
          type : "left"
          where: $db.Linha.id ==? $db.Produto.linha_id
        }
        Tipo    : {
          table: "Tipo"
          type : "left"
          where: $db.Tipo.id ==? $db.Produto.tipo_id
        }
        Nivel   : {
          table: "Nivel"
          type : "left"
          where: $db.Nivel.id ==? $db.Produto.nivel_id
        }
        Borda   : {
          table: "Borda"
          type : "left"
          where: $db.Borda.id ==? $db.item.borda_id
        }
      }
    
      where = $db.item.orca_id == $input.orca_id
      sort = {item.id: "asc"}
      eval = {
        Descricao: $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome|concat:" "|concat:$db.Borda.nome
      }
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "orca_id"
        "produto_id"
        "ipi"
        "imp"
        "vlr_custo"
        "und_produto"
        "larg"
        "comp"
        "larg_fc"
        "comp_fc"
        "borda_id"
        "vlr_cst_borda"
        "und_borda"
        "tipo_fator_id"
        "fator_de_corte_id"
        "detalhe_id"
        "variacao_id"
        "margem"
        "qtd"
        "vlr_cst_unit"
        "vlr_cst_unit_ipi"
        "vlr_cst_unit_imp"
        "vlr_vnd_unit"
        "vlr_vnd_unit_ipi"
        "vlr_vnd_unit_imp"
        "vlr_lucro_unit"
        "vlr_vnd_unit_b2b"
        "descricao"
        "area_user"
        "area_calc"
        "vlr_cst_nota_unit"
        "vlr_cst_entrada_unit"
        "valor_difal_unit"
        "vlr_credito_icms_unit"
        "aliq_inter"
        "aliq_interna"
        "perc_difal"
        "vlr_frete_b2b_unit"
        "vlr_st_unit"
        "vlr_custo_fiscal_unit"
        "eh_importado"
        "perc_margem_real"
        "com_medida_exata"
        "porcentagem_acrescimo"
        "vlr_vnd_unit_bruto"
        "detalhes_calculo"
        "Descricao"
      ]
    } as $itens
  
    // 1. Preparação da soma total dos itens para validação da faixa de Frete B2B
  
    api.lambda {
      code = """
        const itens = $var.itens || [];
        const orca = $var.Orca_0 || {};
        
        const desconto = Number(orca.desconto) || 0;
        const frtB2C = Number(orca.frtB2C) || 0;
        
        const inputMargem = $input ? Number($input.newMargem) : 0;
        const markupAlvo = (inputMargem > 0) ? inputMargem : (Number(orca.margem) || 0);
        
        const itensComCustoBase = itens.map(item => {
          const qtd = Number(item.qtd) || 1;
          const vlr_cst_nota_unit = Number(item.vlr_cst_nota_unit) || Number(item.vlr_cst_unit_ipi) || Number(item.vlr_cst_unit) || 0;
          const custo_total_nota_item = vlr_cst_nota_unit * qtd;
        
          return {
            ...item,
            qtd,
            vlr_cst_nota_unit,
            custo_total_nota_item
          };
        });
        
        const total_custo_nota = itensComCustoBase.reduce((acc, i) => acc + i.custo_total_nota_item, 0);
        
        return {
          total_custo_nota: Number(total_custo_nota.toFixed(4)),
          itensComCustoBase,
          markupAlvo,
          desconto,
          frtB2C
        };
        """
      timeout = 10
    } as $soma_itens
  
    // 2. Cálculo dinâmico do Frete B2B Kapazi
  
    function.run fCalculaFrete {
      input = {
        valor_total_compra: $soma_itens.total_custo_nota
        frt_b2b           : $input.frt_b2b
        frt_b2b_informado : $input.frt_b2b_informado
      }
    } as $frete_b2b_total
  
    // 3. Rateio do Frete, Cálculo dos Impostos (ST/DIFAL/Crédito) e Venda com Markup
  
    api.lambda {
      code = """
        const itensComCustoBase = $var.soma_itens.itensComCustoBase || [];
        const total_custo_nota = $var.soma_itens.total_custo_nota || 0;
        const frete_b2b_total = Number($var.frete_b2b_total) || 0;
        
        const orca = $var.Orca_0 || {};
        const desconto = Number(orca.desconto) || 0;
        const frtB2C = Number(orca.frtB2C) || 0;
        const maoDeObra = Number(orca.mao_de_obra) || 0;
        
        const inputMargem = $input ? Number($input.newMargem) : 0;
        const markupAlvo = (inputMargem > 0) ? inputMargem : (Number(orca.margem) || 0);
        
        // Rateio do Frete B2B e Custos Fiscais / Entrada
        
        const itensComCustoEntrada = itensComCustoBase.map(item => {
          const qtd = Number(item.qtd) || 1;
          const difal_unit = Number(item.valor_difal_unit) || 0;
          const credito_unit = Number(item.vlr_credito_icms_unit) || 0;
          const st_unit = Number(item.vlr_st_unit) || Number(item.vlr_st) || 0;
          
          const cst_nota_unit = Number(item.vlr_cst_nota_unit) || 0;
          const custo_total_nota_item = cst_nota_unit * qtd;
        
          const ratio = total_custo_nota > 0 ? (custo_total_nota_item / total_custo_nota) : 0;
          const frete_rateado_total = frete_b2b_total * ratio;
          const vlr_frete_b2b_unit = frete_rateado_total / qtd;
        
          // Custo Fiscal Unitário e Total — espelha Precificar:
          // MEI/Simples soma DIFAL (sem crédito); Lucro Real/Presumido abate o crédito ICMS
          // (DIFAL não entra no custo na revenda).
          
          const vlr_custo_fiscal_unit = credito_unit > 0
            ? cst_nota_unit + st_unit - credito_unit
            : cst_nota_unit + st_unit + difal_unit;
          const custo_fiscal_total = vlr_custo_fiscal_unit * qtd;
        
          // Custo Real de Entrada Unitário e Total (+ Frete B2B)
          
          const vlr_cst_entrada_unit = vlr_custo_fiscal_unit + vlr_frete_b2b_unit;
          const custo_entrada_total = vlr_cst_entrada_unit * qtd;
        
          return {
            ...item,
            qtd,
            cst_nota_unit,
            custo_total_nota_item,
            difal_unit,
            credito_unit,
            st_unit,
            vlr_frete_b2b_unit,
            frete_rateado_total,
            vlr_custo_fiscal_unit,
            custo_fiscal_total,
            vlr_cst_entrada_unit,
            custo_entrada_total
          };
        });
        
        const cst_tot = itensComCustoEntrada.reduce((acc, i) => acc + i.custo_entrada_total, 0);
        
        // Acumulados do Cabeçalho
        const vlr_st_tot = itensComCustoEntrada.reduce((acc, i) => acc + (i.st_unit * i.qtd), 0);
        const valor_difal_tot = itensComCustoEntrada.reduce((acc, i) => acc + (i.difal_unit * i.qtd), 0);
        const vlr_credito_icms_tot = itensComCustoEntrada.reduce((acc, i) => acc + (i.credito_unit * i.qtd), 0);
        const vlr_custo_fiscal_tot = itensComCustoEntrada.reduce((acc, i) => acc + i.custo_fiscal_total, 0);
        const vlr_ipi_tot = itensComCustoEntrada.reduce((acc, i) => acc + ((Number(i.vlr_cst_unit_ipi) || 0) * i.qtd), 0);
        
        // Venda Bruta e Rateio do Desconto
        const itensComVendaBruta = itensComCustoEntrada.map(item => {
          const venda_bruta_item = item.custo_entrada_total * (1 + (markupAlvo / 100));
          const vlr_vnd_unit_bruto = venda_bruta_item / item.qtd;
          return { ...item, venda_bruta_item, vlr_vnd_unit_bruto };
        });
        
        const total_venda_bruta = itensComVendaBruta.reduce((acc, i) => acc + i.venda_bruta_item, 0);
        
        const itensComVendaFinal = itensComVendaBruta.map(item => {
          const ratioVenda = total_venda_bruta > 0 ? (item.venda_bruta_item / total_venda_bruta) : 0;
          const desconto_rateado_item = desconto * ratioVenda;
          const venda_liquida_item = item.venda_bruta_item - desconto_rateado_item;
        
          const vlr_vnd_unit = venda_liquida_item / item.qtd;
          const vlr_lucro_unit = vlr_vnd_unit - item.vlr_cst_entrada_unit;
          const perc_margem_real = vlr_vnd_unit > 0 ? (vlr_lucro_unit / vlr_vnd_unit) * 100 : 0;
        
          return {
            ...item,
            venda_liquida_item,
            vlr_vnd_unit,
            vlr_lucro_unit,
            perc_margem_real
          };
        });
        
        const vnd_tot = total_venda_bruta - desconto;
        const luc_tot = vnd_tot - cst_tot;
        const markup_efetivo = cst_tot > 0 ? ((vnd_tot - cst_tot) / cst_tot) * 100 : markupAlvo;
        const margem_real_total = vnd_tot > 0 ? (luc_tot / vnd_tot) * 100 : 0;
        
        return {
          itensParaUpdate: itensComVendaFinal.map(i => ({
            id  : i.id,
            data: {
              vlr_cst_nota_unit    : Number(i.cst_nota_unit.toFixed(4)),
              vlr_st_unit          : Number(i.st_unit.toFixed(4)),
              vlr_custo_fiscal_unit: Number(i.vlr_custo_fiscal_unit.toFixed(4)),
              vlr_frete_b2b_unit   : Number(i.vlr_frete_b2b_unit.toFixed(4)),
              vlr_cst_entrada_unit : Number(i.vlr_cst_entrada_unit.toFixed(4)),
              vlr_vnd_unit         : Number(i.vlr_vnd_unit.toFixed(4)),
              vlr_vnd_unit_b2b     : Number(i.vlr_vnd_unit.toFixed(4)),
              vlr_vnd_unit_bruto   : Number(i.vlr_vnd_unit_bruto.toFixed(4)),
              vlr_lucro_unit       : Number(i.vlr_lucro_unit.toFixed(4)),
              margem               : Number(markupAlvo.toFixed(4)),
              perc_margem_real     : Number(i.perc_margem_real.toFixed(4))
            }
          })),
          itemS: itensComVendaFinal.map(i => ({
            ...i,
            vlr_cst_nota_unit    : Number(i.cst_nota_unit.toFixed(4)),
            vlr_st_unit          : Number(i.st_unit.toFixed(4)),
            vlr_custo_fiscal_unit: Number(i.vlr_custo_fiscal_unit.toFixed(4)),
            vlr_frete_b2b_unit   : Number(i.vlr_frete_b2b_unit.toFixed(4)),
            vlr_cst_entrada_unit : Number(i.vlr_cst_entrada_unit.toFixed(4)),
            vlr_vnd_unit         : Number(i.vlr_vnd_unit.toFixed(4)),
            vlr_vnd_unit_b2b     : Number(i.vlr_vnd_unit.toFixed(4)),
            vlr_vnd_unit_bruto   : Number(i.vlr_vnd_unit_bruto.toFixed(4)),
            vlr_lucro_unit       : Number(i.vlr_lucro_unit.toFixed(4)),
            margem               : Number(markupAlvo.toFixed(4)),
            perc_margem_real     : Number(i.perc_margem_real.toFixed(4))
          })),
          totais: {
            cst_tot              : Number(cst_tot.toFixed(4)),
            venda_bruta_tot      : Number(total_venda_bruta.toFixed(4)),
            vlr_st_tot           : Number(vlr_st_tot.toFixed(4)),
            valor_difal_tot      : Number(valor_difal_tot.toFixed(4)),
            vlr_credito_icms_tot : Number(vlr_credito_icms_tot.toFixed(4)),
            vlr_custo_fiscal_tot : Number(vlr_custo_fiscal_tot.toFixed(4)),
            vlr_ipi_tot          : Number(vlr_ipi_tot.toFixed(4)),
            vnd_tot              : Number(vnd_tot.toFixed(4)),
            luc_tot              : Number(luc_tot.toFixed(4)),
            vnd_B2B_tot          : Number(vnd_tot.toFixed(4)),
            vnd_B2B_B2C_tot      : Number((vnd_tot + frtB2C + maoDeObra).toFixed(4)),
            margem               : Number(markup_efetivo.toFixed(4)),
            markup_alvo          : Number(markupAlvo.toFixed(4)),
            markup_efetivo       : Number(markup_efetivo.toFixed(4)),
            margem_real_total    : Number(margem_real_total.toFixed(4)),
            frete_b2b_total      : Number(frete_b2b_total.toFixed(4)),
            desconto             : Number(desconto.toFixed(4)),
            frtB2C               : Number(frtB2C.toFixed(4)),
            mao_de_obra          : Number(maoDeObra.toFixed(4)),
            total_itens          : itensComVendaFinal.length
          }
        };
        """
      timeout = 10
    } as $recalc
  
    // 4. Atualização dos itens com os novos valores unitários (bulk = 1 round-trip)
  
    conditional {
      if (($recalc.itensParaUpdate|count) > 0) {
        db.bulk.patch item {
          items = $recalc.itensParaUpdate
        } as $itens_patch
      }
    }
  
    // 5. Atualização completa do cabeçalho ORCA (Custos + Vendas + Impostos Totais)
  
    db.add_or_edit Orca {
      field_name = "id"
      field_value = $input.orca_id
      enforce_hidden_fields = false
      data = {
        margem              : $recalc.totais.markup_alvo
        markup_alvo         : $recalc.totais.markup_alvo
        markup_efetivo      : $recalc.totais.markup_efetivo
        venda_bruta_tot     : $recalc.totais.venda_bruta_tot
        frtB2B              : $recalc.totais.frete_b2b_total
        cst_tot             : $recalc.totais.cst_tot
        vnd_tot             : $recalc.totais.vnd_tot
        luc_tot             : $recalc.totais.luc_tot
        vnd_B2B_tot         : $recalc.totais.vnd_B2B_tot
        vnd_B2B_B2C_tot     : $recalc.totais.vnd_B2B_B2C_tot
        mao_de_obra         : $recalc.totais.mao_de_obra
        vlr_st_tot          : $recalc.totais.vlr_st_tot
        valor_difal_tot     : $recalc.totais.valor_difal_tot
        vlr_credito_icms_tot: $recalc.totais.vlr_credito_icms_tot
        vlr_custo_fiscal_tot: $recalc.totais.vlr_custo_fiscal_tot
        vlr_ipi_tot         : $recalc.totais.vlr_ipi_tot
        total_itens         : $recalc.totais.total_itens
      }
    } as $Orca_1
  
  }

  response = {totais: $recalc.totais, ORCA_1: $Orca_1, itemS: $recalc.itemS}
  guid = "MxrjpIDe_bc0YwRP0lpsrg"
}