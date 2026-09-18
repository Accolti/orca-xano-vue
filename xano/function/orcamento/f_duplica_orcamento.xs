// Função duplica o orçamento.
function "Orcamento/f_DuplicaOrcamento" {
  input {
    int orca_id? {
      table = "Orca"
    }
  
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
    } as $Orca1
  
    db.query item {
      where = $db.item.orca_id == $Orca1.id
      return = {type: "list"}
    } as $item1
  
    db.transaction {
      stack {
        function.run Novo_Numero_Orcamento {
          input = {id_do_Usuario: $input.user_id}
        } as $novoNum_Orc
      
        db.add Orca {
          enforce_hidden_fields = false
          data = {
            created_at                : "now"
            cod_orca                  : $novoNum_Orc.newOrca
            cliente_id                : $Orca1.cliente_id
            frtB2B                    : $Orca1.frtB2B
            frtB2C                    : $Orca1.frtB2C
            validade                  : $Orca1.validade
            user_id                   : $input.user_id
            margem                    : $Orca1.margem
            markup_alvo               : $Orca1.markup_alvo
            markup_efetivo            : $Orca1.markup_efetivo
            cst_tot                   : $Orca1.cst_tot
            luc_tot                   : $Orca1.luc_tot
            vnd_tot                   : $Orca1.vnd_tot
            vnd_B2B_tot               : $Orca1.vnd_B2B_tot
            vnd_B2B_B2C_tot           : $Orca1.vnd_B2B_B2C_tot
            venda_bruta_tot           : $Orca1.venda_bruta_tot
            desconto                  : $Orca1.desconto
            mao_de_obra               : $Orca1.mao_de_obra
            vlr_st_tot                : $Orca1.vlr_st_tot
            valor_difal_tot           : $Orca1.valor_difal_tot
            vlr_credito_icms_tot      : $Orca1.vlr_credito_icms_tot
            vlr_custo_fiscal_tot      : $Orca1.vlr_custo_fiscal_tot
            vlr_ipi_tot               : $Orca1.vlr_ipi_tot
            total_itens               : $Orca1.total_itens
            observacao                : $Orca1.observacao
            condicoes_pagamento       : $Orca1.condicoes_pagamento
            condicoes_pagamento_params: $Orca1.condicoes_pagamento_params
            regime_id                 : $Orca1.regime_id
            uf_origem                 : $Orca1.uf_origem
            uf_destino                : $Orca1.uf_destino
            desconto_aprovado         : true
            desconto_status           : "aprovado"
          }
        } as $Orca2
      
        foreach ($item1) {
          each as $item {
            db.add item {
              enforce_hidden_fields = false
              data = {
                created_at           : "now"
                orca_id              : $Orca2.id
                produto_id           : $item.produto_id
                ipi                  : $item.ipi
                imp                  : $item.imp
                vlr_custo            : $item.vlr_custo
                base_calculo         : $item.base_calculo
                und_produto          : $item.und_produto
                larg                 : $item.larg
                comp                 : $item.comp
                larg_fc              : $item.larg_fc
                comp_fc              : $item.comp_fc
                borda_id             : $item.borda_id
                vlr_cst_borda        : $item.vlr_cst_borda
                und_borda            : $item.und_borda
                tipo_fator_id        : $item.tipo_fator_id
                fator_de_corte_id    : $item.fator_de_corte_id
                detalhe_id           : $item.detalhe_id
                variacao_id          : $item.variacao_id
                margem               : $item.margem
                qtd                  : $item.qtd
                vlr_cst_unit         : $item.vlr_cst_unit
                vlr_cst_unit_ipi     : $item.vlr_cst_unit_ipi
                vlr_cst_unit_imp     : $item.vlr_cst_unit_imp
                vlr_vnd_unit         : $item.vlr_vnd_unit
                vlr_vnd_unit_ipi     : $item.vlr_vnd_unit_ipi
                vlr_vnd_unit_imp     : $item.vlr_vnd_unit_imp
                vlr_vnd_unit_b2b     : $item.vlr_vnd_unit_b2b
                vlr_lucro_unit       : $item.vlr_lucro_unit
                descricao            : $item.descricao
                area_user            : $item.area_user
                area_calc            : $item.area_calc
                vlr_cst_nota_unit    : $item.vlr_cst_nota_unit
                vlr_cst_entrada_unit : $item.vlr_cst_entrada_unit
                valor_difal_unit     : $item.valor_difal_unit
                vlr_credito_icms_unit: $item.vlr_credito_icms_unit
                aliq_inter           : $item.aliq_inter
                aliq_interna         : $item.aliq_interna
                perc_difal           : $item.perc_difal
                vlr_frete_b2b_unit   : $item.vlr_frete_b2b_unit
                vlr_st_unit          : $item.vlr_st_unit
                vlr_custo_fiscal_unit: $item.vlr_custo_fiscal_unit
                eh_importado         : $item.eh_importado
                perc_margem_real     : $item.perc_margem_real
                com_medida_exata     : $item.com_medida_exata
                porcentagem_acrescimo: $item.porcentagem_acrescimo
                fc                   : $item.fc
                vlr_vnd_unit_bruto   : $item.vlr_vnd_unit_bruto
                detalhes_calculo     : $item.detalhes_calculo
              }
            } as $item2
          }
        }
      
        !debug.stop {
          value = $item2
        }
      }
    }
  }

  response = {orca: $Orca2}
  tags = ["orcamento"]
  guid = "udr65PyN-4WM_PlBsZl22QpZdVw"
}