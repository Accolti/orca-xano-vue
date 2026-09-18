// Edit item record
query "item/{item_id}" verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int item_id filters=min:1
    dblink {
      table = "item"
    }
  }

  stack {
    !debug.stop {
      value = $input.item_id
    }
  
    function.run item_change {
      input = {
        item_id          : $input.item_id
        orca_id          : $input.orca_id
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
        vlr_cst_unit_ipi : $input.vlr_cst_unit_ipi
        vlr_cst_unit_imp : $input.vlr_cst_unit_imp
        vlr_vnd_unit     : $input.vlr_vnd_unit
        vlr_vnd_unit_ipi : $input.vlr_vnd_unit_ipi
        vlr_vnd_unit_imp : $input.vlr_vnd_unit_imp
        vlr_vnd_unit_b2b : $input.vlr_vnd_unit_b2b
        descricao        : $input.descricao
        area_user        : $input.area_user
        area_calc        : $input.area_calc
      }
    } as $func_1
  }

  response = $func_1
  guid = "i9GghbdUQmRcRvPYyDDDoj64u7k"
}