// Edit Orcamento record
query "orcamento/{orcamento_id}" verb=POST {
  api_group = "Default"

  input {
    int orcamento_id? filters=min:1
    dblink {
      table = ""
    }
  }

  stack {
    db.edit "" {
      field_name = "id"
      field_value = $input.orcamento_id
      enforce_hidden_fields = false
      data = {
        orca_codigo        : $input.orca_codigo
        diasDeValidadeTeste: $input.diasDeValidadeTeste
        produto_id         : $input.produto_id
        valor_custo        : $input.valor_custo
        und_produto        : $input.und_produto
        comp               : $input.comp
        larg               : $input.larg
        comp_fc            : $input.comp_fc
        larg_fc            : $input.larg_fc
        borda_id           : $input.borda_id
        valor_custo_borda  : $input.valor_custo_borda
        und_borda          : $input.und_borda
        tipo_fator_id      : $input.tipo_fator_id
        fator_de_corte_id  : $input.fator_de_corte_id
        margem             : $input.margem
        frete_b2b          : $input.frete_b2b
        frete_b2c          : $input.frete_b2c
        IMP                : $input.IMP
        IPI                : $input.IPI
        valor_cst_unit     : $input.valor_cst_unit
        valor_vnd_unit     : $input.valor_vnd_unit
        valor_lucro_unit   : $input.valor_lucro_unit
        valor_vnd_unit_b2b : $input.valor_vnd_unit_b2b
        qtd                : $input.qtd
        und_qtd            : $input.und_qtd
        user_id            : $input.user_id
        descricao          : $input.descricao
      }
    } as $orcamento
  }

  response = $orcamento
  guid = "n0Vux7BgFuhRESEZaq546V3G7Yo"
}