// A função f_Orcamento_Orquestrador é o motor central de precificação e recalculo do sistema. Ela consulta as regras fiscais (Regra_Fiscal e Aliquotas_icms), processa o cálculo dinâmico de ICMS-ST e margens, e consolida os totais do orçamento em tempo real.
// 
// Uso do parâmetro orca_id:
// 
// Passe o orca_id (ID existente): Sempre que for recalcular ou atualizar um orçamento já criado (ex: inserção/remoção de itens, alteração de quantidades ou mudança de condição comercial).
// 
// Deixe o orca_id nulo (null): Apenas no momento de criar um orçamento novo do zero, permitindo que a função gere um novo registro no banco.
function f_Orcamento_Orquestrador {
  input {
    int produto_id? {
      table = "Produto"
    }
  
    int borda_id? {
      table = "Borda"
    }
  
    int variacao_id? {
      table = "Variacao"
    }
  
    // Se for area a largura deverá ser zero
    decimal comprimento_ou_area?
  
    decimal largura?
    decimal quantidade?
    decimal markup?
    int user_id? {
      table = "User"
    }
  
    int orca_id? {
      table = "Orca"
    }
  
    // Item em edição (0/ausente = item novo) — excluído do somatório do frete
    int item_id? {
      table = "item"
    }
  
    // Vendedor marcou medida exata → aplica porcentagem_acrescimo do produto no custo
    bool com_medida_exata?
  
    // Produto composto (COMPOSTO): lados do perímetro com rampa e cantos
    bool rampa_larg1?
  
    bool rampa_comp1?
    bool rampa_larg2?
    bool rampa_comp2?
    int qtd_cantos?
  }

  stack {
    function.run f_buscador_produto {
      input = {
        produto_id : $input.produto_id
        borda_id   : $input.borda_id
        variacao_id: $input.variacao_id
      }
    } as $Produto
  
    // Guarda: produto não encontrado (ex.: variação não pertence ao produto selecionado)
    // gera mensagem clara em vez de "Unable to locate var: Produto.*".
    precondition (($Produto|count) > 0) {
      error_type = "badrequest"
      error = "Produto não encontrado para a seleção. Se há variação escolhida, confira se ela pertence ao produto (detalhe_id). Verifique o catálogo."
    }
  
    !debug.stop {
      value = $Produto
    }
  
    function.run SumarizaItensOrcamento {
      input = {orca_id: $input.orca_id, exclude_item_id: $input.item_id}
    } as $somaItens_custo_nota|first
  
    // Abaixo soma dos custos dos itens que já foram acrescentados para essa compor o frete
  
    var $custo_nota_total_para_frete {
      value = 0
    }
  
    // Orçamento sem itens → aggregate retorna null → frete usa só o item atual
    conditional {
      if ($somaItens_custo_nota != null) {
        var.update $custo_nota_total_para_frete {
          value = $somaItens_custo_nota.cst_nota_orca|first_notnull:0
        }
      }
    }
  
    // Config efetiva: filhos herdam do topo da cadeia (admin/admin_geral)
    function.run f_perfil_efetivo {
      input = {user_id: $auth.id}
    } as $UsEfet
  
    db.query Organizacao {
      where = $db.Organizacao.id == $UsEfet.organizacao_id
      return = {type: "list"}
    } as $Org
  
    var $tipo_calculo {
      value = $Produto.Base_de_Calculo|first|to_upper
    }
  
    var $borda_unidade {
      value = $Produto.borda_unidade|first|to_upper
    }
  
    // Resultado do cálculo por base — garantimos que nunca fica indefinido.
    var $mod1 {
      value = null
    }
  
    switch ($tipo_calculo) {
      case ("M2") {
        function.run f_valor_custo_m2 {
          input = {
            comprimento     : $input.comprimento_ou_area
            largura         : $input.largura
            quantidade      : $input.quantidade
            prd             : $Produto
            com_medida_exata: $input.com_medida_exata
          }
        } as $mod1
      } break
    
      case ("ML") {
        function.run f_valor_custo_ml {
          input = {
            comprimento_ou_area: $input.comprimento_ou_area
            largura            : $input.largura
            produto            : $Produto
            com_medida_exata   : $input.com_medida_exata
          }
        } as $mod1
      } break
    
      case ("UND") {
        function.run f_valor_custo_und {
          input = {quantidade: $input.quantidade, prd: $Produto}
        } as $mod1
      } break
    
      case ("KIT") {
        function.run f_valor_custo_kit {
          input = {
            comprimento_ou_area: $input.comprimento_ou_area
            largura            : $input.largura
            produto            : $Produto
          }
        } as $mod1
      } break
    
      case ("COMPOSTO") {
        // Produto composto: dispatch pela regra de composição (tipo_composto).
        // PLAYKAP = placas/rampas/cantoneiras (piso modular).
        conditional {
          if (($Produto.tipo_composto|first|to_upper) == "PLAYKAP") {
            function.run f_valor_custo_playkap {
              input = {
                comprimento_ou_area: $input.comprimento_ou_area
                largura            : $input.largura
                rampa_larg1        : $input.rampa_larg1
                rampa_comp1        : $input.rampa_comp1
                rampa_larg2        : $input.rampa_larg2
                rampa_comp2        : $input.rampa_comp2
                qtd_cantos         : $input.qtd_cantos
                produto            : $Produto
              }
            } as $mod1
          }
        }
      } break
    }
  
    // Garante que o cálculo da base foi resolvido (mod1). Se o produto composto não
    // tiver tipo_composto válido, cai aqui com erro claro em vez de "Missing var entry".
    precondition ($mod1 != null) {
      error_type = "badrequest"
      error = "Não foi possível calcular o custo do produto (base "
        |concat:$tipo_calculo:" | tipo_composto não configurado para COMPOSTO)."
    }
  
    // UF de origem = UF do fornecedor (Organização do usuário). Sem organização
    // escolhida (organizacao_id vazio/"0"), usa o default PR (Kapazi) — evita quebra
    // de $Org.uf quando a query de Organização volta vazia.
    var $uf_origem {
      value = "PR"
    }
  
    var $primeira_org {
      value = $Org|first
    }
  
    conditional {
      if ($primeira_org != null) {
        var.update $uf_origem {
          value = $primeira_org.uf|first_notnull:"PR"
        }
      }
    }
  
    function.run Precificar {
      input = {
        custo_nota     : $mod1.valores.custo_nota_tot
        uf_origem      : $uf_origem|to_upper
        uf_destino     : $UsEfet.uf
        regime_empresa : ""
        regime_id      : $UsEfet.regime_id
        eh_importado   : $Produto.eh_importado|first
        tem_st         : $Produto.st|first
        mva_padrao     : $Produto.mva_padrao|first
        aliq_st_interna: $Produto.aliq_st_interna|first
      }
    } as $precif
  
    !debug.stop {
      value = $mod1
    }
  
    var $qtd {
      value = $mod1.quantidade
    }
  
    var $largura_fc {
      value = $mod1.largura_fc
    }
  
    var $larg {
      value = $mod1.largura
    }
  
    var $comp {
      value = $mod1.comprimento
    }
  
    var $comprimento_fc {
      value = $mod1.comprimento_fc
    }
  
    var $custo_nota_tot {
      value = $mod1.valores.custo_nota_tot
    }
  
    var $valor_difal_tot {
      value = $precif.valor_difal
    }
  
    var $valor_difal_unit {
      value = $precif.valor_difal|divide:$qtd
    }
  
    // Captura e divide o ST vindo da função Precificar
  
    var $valor_st_tot {
      value = $precif.valor_st
    }
  
    var $valor_st_unit {
      value = $precif.valor_st|divide:$qtd
    }
  
    var $credito_icms_tot {
      value = $precif.credito_icms
    }
  
    var $credito_icms_unit {
      value = $precif.credito_icms|divide:$qtd
    }
  
    var.update $custo_nota_total_para_frete {
      value = $custo_nota_total_para_frete|add:$custo_nota_tot
    }
  
    function.run fCalculaFrete {
      input = {
        valor_total_compra: $custo_nota_total_para_frete
        frt_b2b           : $UsEfet.frtB2B|first_notnull:0
        frt_b2b_informado : true
      }
    } as $frete_b2b
  
    var $frete_b2b {
      value = $frete_b2b
    }
  
    var $custo_kapazi_custo_nota_frete_tot {
      value = $custo_nota_tot|add:$frete_b2b
    }
  
    var $custo_fiscal_tot {
      value = $precif.custo_fiscal
    }
  
    var $custo_fiscal_unit {
      value = $precif.custo_fiscal|divide:$qtd
    }
  
    // Valor de custo unitatio
  
    var $valor_custo_unit {
      value = $mod1.valores.custo_total|divide:$qtd
    }
  
    // Frete rateado ao item atual (proporcional ao custo_nota) — bate com o recálculo pós-inserção.
    var $frete_rateado_tot {
      value = $frete_b2b
        |multiply:($custo_nota_tot
          |divide:$custo_nota_total_para_frete
        )
    }
  
    var $custo_real_entrada_tot {
      value = $custo_fiscal_tot|add:$frete_rateado_tot
    }
  
    var $custo_real_entrada_unit {
      value = $custo_real_entrada_tot|divide:$qtd
    }
  
    var $valor_venda_tot {
      value = $custo_real_entrada_tot
        |multiply:(1|add:($input.markup|divide:100))
    }
  
    var $valor_venda_unit {
      value = $valor_venda_tot|divide:$qtd
    }
  
    var $lucro_tot {
      value = $valor_venda_tot|subtract:$custo_real_entrada_tot
    }
  
    var $lucro_unit {
      value = $lucro_tot|divide:$qtd
    }
  
    var $margem_real {
      value = $lucro_tot
        |divide:$valor_venda_tot
        |multiply:100
    }
  
    var $produto_id {
      value = $input.produto_id
    }
  
    var $borda_id {
      value = $input.borda_id
    }
  
    var $vlr_cst_materia_prima {
      value = $mod1.valores.custo_materia_prima
    }
  
    var $vlr_cst_borda {
      value = $mod1.valores.custo_borda
    }
  
    var $vlr_ipi_unit {
      value = $mod1.valores.valor_ipi_unit
    }
  
    var $vlr_perc_difal {
      value = $precif.perc_difal
    }
  
    var $vlr_aliq_inter {
      value = $precif.aliq_inter
    }
  
    var $vlr_aliq_interna {
      value = $precif.aliq_interna
    }
  
    var $uf_origem {
      value = $precif.uf_origem
    }
  
    var $uf_destino {
      value = $precif.uf_destino
    }
  
    var $regime_id {
      value = $UsEfet.regime_id
    }
  
    !debug.stop {
      value = $mod1.fator_de_corte_id
    }
  }

  response = {
    produto_id           : $input.produto_id
    borda_id             : $input.borda_id
    variacao_id          : $input.variacao_id
    qtd                  : $qtd
    comp                 : $comp
    larg                 : $larg
    comp_fc              : $comprimento_fc
    larg_fc              : $largura_fc
    vlr_cst_unit         : $custo_nota_tot|divide:$qtd
    vlr_custo_nota_unit  : $custo_nota_tot|divide:$qtd
    vlr_custo_nota_tot   : $custo_nota_tot
    vlr_difal_unit       : $valor_difal_unit
    vlr_difal_tot        : $valor_difal_tot
    vlr_st_unit          : $valor_st_unit
    vlr_st_tot           : $valor_st_tot
    vlr_credito_icms_unit: $credito_icms_unit
    vlr_credito_icms_tot : $credito_icms_tot
    vlr_custo_fiscal_unit: $custo_fiscal_unit
    vlr_custo_fiscal_tot : $custo_fiscal_tot
    eh_importado         : $Produto.eh_importado|first
    frete_b2b            : $frete_b2b
    vlr_frete_b2b_unit   : $frete_rateado_tot|divide:$qtd
    vlr_cst_entrada_unit : $custo_real_entrada_unit
    vlr_cst_entrada_tot  : $custo_real_entrada_tot
    vlr_vnd_unit         : $valor_venda_unit
    vlr_vnd_tot          : $valor_venda_tot
    vlr_lucro_unit       : $lucro_unit
    vlr_lucro_tot        : $lucro_tot
    perc_marguem_real    : $margem_real
    margem               : $input.markup
    ipi                  : $Produto.ipi|first
    base_calculo         : $Produto.Base_de_Calculo|first|to_upper
    und_produto          : $Produto.Unidade|first
    und_borda            : $borda_unidade
    vlr_cst_materia_prima: $vlr_cst_materia_prima
    vlr_cst_borda        : $vlr_cst_borda
    vlr_ipi_unit         : $vlr_ipi_unit
    vlr_perc_difal       : $vlr_perc_difal
    vlr_aliq_inter       : $vlr_aliq_inter
    vlr_aliq_interna     : $vlr_aliq_interna
    uf_origem            : $uf_origem
    uf_destino           : $uf_destino
    regime_id            : $regime_id
    fc                   : $mod1.fc
    fator_de_corte_id    : $mod1.fator_de_corte_id
    tipo_fator_id        : $mod1.tipo_fator_id
    com_medida_exata     : $mod1.com_medida_exata
    porcentagem_acrescimo: $mod1.acrescimo_medida_exata
    detalhes_calculo     : $mod1.detalhes_calculo
  }

  guid = "SgmUjHqaYgp00-63iFOfE4Zc-Rg"
}