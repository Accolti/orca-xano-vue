function item_change {
  input {
    int item_id? filters=min:1
    dblink {
      table = "item"
    }
  }

  stack {
    db.get item {
      field_name = "id"
      field_value = $input.item_id
    } as $item
  
    db.edit item {
      field_name = "id"
      field_value = $input.item_id
      enforce_hidden_fields = false
      data = {
        produto_id       : $input.produto_id|first_notempty:$item.produto_id
        ipi              : $input.ipi|first_notnull:$item.ipi
        imp              : $input.imp|first_notnull:$item.imp
        vlr_custo        : $input.vlr_custo|first_notempty:$item.vlr_custo
        und_produto      : $input.und_produto|first_notempty:$item.und_produto
        larg             : $input.larg|first_notempty:$item.larg
        comp             : $input.comp|first_notempty:$item.comp
        larg_fc          : $input.larg_fc|first_notempty:$item.larg_fc
        comp_fc          : $input.comp_fc|first_notempty:$item.comp_fc
        borda_id         : $input.borda_id|first_notempty:$item.borda_id
        vlr_cst_borda    : $input.vlr_cst_borda|first_notnull:$item.vlr_cst_borda
        und_borda        : $input.und_borda|first_notempty:$item.und_borda
        tipo_fator_id    : $input.tipo_fator_id|first_notempty:$item.tipo_fator_id
        fator_de_corte_id: $input.fator_de_corte_id|first_notempty:$item.fator_de_corte_id
        detalhe_id       : $input.detalhe_id|first_notempty:$item.detalhe_id
        variacao_id      : $input.variacao_id|first_notempty:$item.variacao_id
        margem           : $input.margem|first_notempty:$item.margem
        qtd              : $input.qtd|first_notempty:$item.qtd
        vlr_cst_unit     : $input.vlr_cst_unit|first_notempty:$item.vlr_cst_unit
        vlr_cst_unit_ipi : $input.vlr_cst_unit_ipi|first_notnull:$item.vlr_cst_unit_ipi
        vlr_cst_unit_imp : $input.vlr_cst_unit_imp|first_notnull:$item.vlr_cst_unit_imp
        vlr_vnd_unit     : $input.vlr_vnd_unit|first_notempty:$item.vlr_vnd_unit
        vlr_vnd_unit_ipi : $input.vlr_vnd_unit_ipi|first_notnull:$item.vlr_vnd_unit_ipi
        vlr_vnd_unit_imp : $input.vlr_vnd_unit_imp|first_notnull:$item.vlr_vnd_unit_imp
        vlr_vnd_unit_b2b : $input.vlr_vnd_unit_b2b|first_notempty:$item.vlr_vnd_unit_b2b
        descricao        : $input.descricao|first_notempty:$item.descricao
        area_user        : $input.area_user|first_notempty:$item.area_user
        area_calc        : $input.area_calc|first_notempty:$item.area_calc
      }
    } as $item
  }

  response = $item
  guid = "sbv8gFlSVo59iiUai4fpRoExYZo"
}