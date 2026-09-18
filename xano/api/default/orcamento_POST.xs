// Add Orcamento record
query orcamento verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = ""
      override = {und_qtd: {hidden: false}}
    }
  }

  stack {
    db.add "" {
      enforce_hidden_fields = false
      data = {
        orca_codigo       : $input.orca_codigo
        created_at        : "now"
        produto_id        : $input.produto_id
        valor_custo       : $input.valor_custo
        und_produto       : $input.und_produto
        comp              : $input.comp
        larg              : $input.larg
        comp_fc           : $input.comp_fc
        larg_fc           : $input.larg_fc
        borda_id          : $input.borda_id
        valor_custo_borda : $input.valor_custo_borda
        und_borda         : $input.und_borda
        tipo_fator_id     : $input.tipo_fator_id
        fator_de_corte_id : $input.fator_de_corte_id
        margem            : $input.margem
        frete_b2b         : $input.frete_b2b
        frete_b2c         : $input.frete_b2c
        IMP               : $input.IMP
        IPI               : $input.IPI
        valor_cst_unit    : $input.valor_cst_unit
        valor_vnd_unit    : $input.valor_vnd_unit
        valor_lucro_unit  : $input.valor_lucro_unit
        valor_vnd_unit_b2b: $input.valor_vnd_unit_b2b
        qtd               : $input.qtd
        und_qtd           : $input.und_qtd
        user_id           : $input.user_id
      }
    } as $orcamento
  }

  response = $orcamento
  guid = "zAu1JABM0VxOWMe3ICRC2GHyJQ8"
}