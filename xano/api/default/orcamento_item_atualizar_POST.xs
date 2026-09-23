// Atualiza um item existente do orçamento (edição de características).
// Grava todos os campos no item (sem first_notempty, aceitando 0 p/ borda/variação),
// recalcula os totais e devolve header + itens atualizados.
query OrcamentoItem_Atualizar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int item_id? {
      table = "item"
    }
  
    int produto_id? {
      table = "Produto"
    }
  
    decimal ipi?
    decimal imp?
    decimal vlr_custo?
    text base_calculo? filters=trim
    text und_produto? filters=trim
    decimal larg?
    decimal comp?
    decimal larg_fc?
    decimal comp_fc?
    int borda_id? {
      table = "Borda"
    }
  
    decimal vlr_cst_borda?
    text und_borda? filters=trim
    int tipo_fator_id? {
      table = "Tipo_Fator"
    }
  
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  
    int detalhe_id? {
      table = "Detalhe"
    }
  
    int variacao_id? {
      table = "Variacao"
    }
  
    decimal margem?
    decimal qtd?
    decimal vlr_cst_unit?
    decimal vlr_cst_unit_ipi?
    decimal vlr_cst_unit_imp?
    decimal vlr_vnd_unit?
    decimal vlr_vnd_unit_ipi?
    decimal vlr_vnd_unit_imp?
    decimal vlr_vnd_unit_b2b?
    decimal vlr_lucro_unit?
    text descricao? filters=trim
    decimal area_user?
    decimal area_calc?
  
    // Campos Fiscais e de Custo Unitários conforme novo Schema
    decimal vlr_cst_nota_unit?
  
    decimal vlr_cst_entrada_unit?
    decimal valor_difal_unit?
    decimal vlr_credito_icms_unit?
    decimal aliq_inter?
    decimal aliq_interna?
    decimal perc_difal?
    decimal vlr_frete_b2b_unit?
    decimal vlr_st_unit?
    decimal vlr_custo_fiscal_unit?
    bool eh_importado?
    decimal perc_margem_real?
  
    // Medida exata (marcada pelo vendedor) — acréscimo já aplicado no custo pelo orquestrador
    bool com_medida_exata?
  
    decimal porcentagem_acrescimo?
  
    // array com os fatores de corte
    decimal[] fc?
  
    // Detalhes do cálculo (produtos compostos/ML) em JSON
    json detalhes_calculo?
  }

  stack {
    db.get item {
      field_name = "id"
      field_value = $input.item_id
    } as $item_existente
  
    precondition ($item_existente != null) {
      error_type = "notfound"
      error = "Item não encontrado."
    }
  
    // Config efetiva (frtB2B) — filhos herdam do topo da cadeia
    function.run f_perfil_efetivo {
      input = {user_id: $auth.id}
    } as $PerfilEfet
  
    db.transaction {
      stack {
        db.edit item {
          field_name = "id"
          field_value = $input.item_id
          enforce_hidden_fields = false
          data = {
            produto_id           : $input.produto_id
            ipi                  : $input.ipi
            imp                  : $input.imp
            vlr_custo            : $input.vlr_custo
            base_calculo         : $input.base_calculo
            und_produto          : $input.und_produto
            larg                 : $input.larg
            comp                 : $input.comp
            larg_fc              : $input.larg_fc
            comp_fc              : $input.comp_fc
            borda_id             : $input.borda_id
            vlr_cst_borda        : $input.vlr_cst_borda
            und_borda            : $input.und_borda
            tipo_fator_id        : $input.tipo_fator_id
            fator_de_corte_id    : $input.fator_de_corte_id
            detalhe_id           : $input.detalhe_id
            variacao_id          : $input.variacao_id
            margem               : $input.margem
            qtd                  : $input.qtd
            vlr_cst_unit         : $input.vlr_cst_unit
            vlr_cst_unit_ipi     : $input.vlr_cst_unit_ipi
            vlr_cst_unit_imp     : $input.vlr_cst_unit_imp
            vlr_vnd_unit         : $input.vlr_vnd_unit
            vlr_vnd_unit_ipi     : $input.vlr_vnd_unit_ipi
            vlr_vnd_unit_imp     : $input.vlr_vnd_unit_imp
            vlr_vnd_unit_b2b     : $input.vlr_vnd_unit_b2b
            vlr_lucro_unit       : $input.vlr_lucro_unit
            descricao            : $input.descricao
            area_user            : $input.area_user
            area_calc            : $input.area_calc
            vlr_cst_nota_unit    : $input.vlr_cst_nota_unit
            vlr_cst_entrada_unit : $input.vlr_cst_entrada_unit
            valor_difal_unit     : $input.valor_difal_unit
            vlr_credito_icms_unit: $input.vlr_credito_icms_unit
            aliq_inter           : $input.aliq_inter
            aliq_interna         : $input.aliq_interna
            perc_difal           : $input.perc_difal
            vlr_frete_b2b_unit   : $input.vlr_frete_b2b_unit
            vlr_st_unit          : $input.vlr_st_unit
            vlr_custo_fiscal_unit: $input.vlr_custo_fiscal_unit
            eh_importado         : $input.eh_importado
            perc_margem_real     : $input.perc_margem_real
            com_medida_exata     : $input.com_medida_exata
            porcentagem_acrescimo: $input.porcentagem_acrescimo
            fc                   : $input.fc
            detalhes_calculo     : $input.detalhes_calculo
          }
        } as $item_editado
      
        // Itens mudaram → limpa as condições de pagamento (ficam desatualizadas)
        db.edit Orca {
          field_name = "id"
          field_value = $item_existente.orca_id
          enforce_hidden_fields = false
          data = {condicoes_pagamento: ""}
        } as $Orca_cond_limpa
      }
    }
  
    // Recálculo dinâmico por somatório (fora da transação)
    function.run Orcamento_Recalcular_Totais {
      input = {
        orca_id           : $item_existente.orca_id
        frt_b2b           : $PerfilEfet.frtB2B|first_notnull:0
        frt_b2b_informado : true
      }
    } as $func_1
  
    db.get Orca {
      field_name = "id"
      field_value = $item_existente.orca_id
      addon = [
        {
          name : "Cliente"
          input: {Cliente_id: $output.cliente_id}
          as   : "_cliente"
        }
      ]
    } as $Orca_1
  }

  response = {
    ORCA_1: $Orca_1
    itemS : $func_1.itemS
    totais: $func_1.totais
  }

  tags = ["orcamento", "novo-sis"]
  guid = "OrcamentoItem-Atualizar-novo-sis"
}