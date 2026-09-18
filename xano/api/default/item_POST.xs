// Add item record
query item verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "item"
      override = {
        orca_id          : {hidden: false}
        borda_id         : {hidden: false}
        detalhe_id       : {hidden: false}
        produto_id       : {hidden: false}
        variacao_id      : {hidden: false}
        vlr_cst_unit_ipi : {hidden: false}
        fator_de_corte_id: {hidden: false}
      }
    }
  }

  stack {
    !function.run post_item {
      input = {item__: $input.item__}
    } as $func_1
  
    function.run post_item {
      input = {
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
      }
    } as $func_2
  }

  response = $func_2
  guid = "eZtyOK9yWNgYG2VSYSX0ubvTb0c"
}