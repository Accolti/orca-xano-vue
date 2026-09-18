function item_ped_func {
  input {
    dblink {
      table = "item_ped"
    }
  }

  stack {
    db.add item_ped {
      enforce_hidden_fields = false
      data = {
        created_at       : "now"
        pedido_id        : $input.pedido_id
        produto_id       : $input.produto_id
        ipi              : $input.ipi
        imp              : $input.imp
        vlr_custo        : $input.vlr_custo
        und_produto      : $input.und_produto
        larg             : $input.larg
        comp             : $input.comp
        larg_fc          : $input.larg_fc
        comp_fc          : $input.comp_fc
        borda_id         : $input.borda_id
        vlr_cst_borda    : $input.vlr_cst_borda
        und_borda        : $input.und_borda
        tipo_fator_id    : $input.tipo_fator_id
        fator_de_corte_id: $input.fator_de_corte_id
        detalhe_id       : $input.detalhe_id
        variacao_id      : $input.variacao_id
        margem           : $input.margem
        qtd              : $input.qtd
        vlr_cst_unit     : $input.vlr_cst_unit
        vlr_cst_tot      : $input.vlr_cst_tot
        vlr_cst_unit_ipi : $input.vlr_cst_unit_ipi
        vlr_cst_tot_ipi  : $input.vlr_cst_tot_ipi
        vlr_cst_unit_imp : $input.vlr_cst_unit_imp
        vlr_cst_tot_imp  : $input.vlr_cst_tot_imp
        vlr_vnd_unit     : $input.vlr_vnd_unit
        vlr_vnd_tot      : $input.vlr_vnd_tot
        vlr_vnd_unit_ipi : $input.vlr_vnd_unit_ipi
        vlr_vnd_tot_ipi  : $input.vlr_vnd_tot_ipi
        vlr_vnd_unit_imp : $input.vlr_vnd_unit_imp
        vlr_vnd_tot_imp  : $input.vlr_vnd_tot_imp
        vlr_vnd_unit_b2b : $input.vlr_vnd_unit_b2b
        vlr_vnd_tot_b2b  : $input.vlr_vnd_tot_b2b
        descricao        : $input.descricao
        area_user        : $input.area_user
        area_calc        : $input.area_calc
      }
    } as $model
  }

  response = $model
  guid = "REXA7OHc_2qC5CU9B5euCRgy3tQ"
}