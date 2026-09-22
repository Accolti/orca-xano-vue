function post_item {
  input {
    dblink {
      table = "item"
      override = {
        borda_id         : {hidden: false}
        descricao        : {hidden: false}
        detalhe_id       : {hidden: false}
        variacao_id      : {hidden: false}
        tipo_fator_id    : {hidden: false}
        detalhes_calculo : {hidden: false}
        fator_de_corte_id: {hidden: false}
      }
    }
  }

  stack {
    db.transaction {
      stack {
        db.add item {
          enforce_hidden_fields = false
          data = {
            created_at           : "now"
            orca_id              : $input.orca_id
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
            detalhe_id           : $input.detalhe_id
            fator_de_corte_id    : $input.fator_de_corte_id
            variacao_id          : $input.variacao_id
            margem               : $input.margem
            qtd                  : $input.qtd
            vlr_cst_unit         : $input.vlr_cst_unit
            vlr_cst_unit_ipi     : $input.vlr_cst_unit_ipi
            vlr_cst_unit_imp     : $input.vlr_cst_unit_imp
            vlr_vnd_unit         : $input.vlr_vnd_unit
            vlr_vnd_unit_ipi     : $input.vlr_vnd_unit_ipi
            vlr_vnd_unit_imp     : $input.vlr_vnd_unit_imp
            vlr_lucro_unit       : $input.vlr_lucro_unit
            vlr_vnd_unit_b2b     : $input.vlr_vnd_unit_b2b
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
        } as $item
      }
    }
  }

  response = $item
  guid = "6kA8_3StgogoTokyNmOs7GdzK0U"
}