function pedido_func {
  input {
    dblink {
      table = "Pedido"
    }
  }

  stack {
    db.add Pedido {
      enforce_hidden_fields = false
      data = {
        created_at         : "now"
        num_ped            : $input.num_ped
        cod_orca           : $input.cod_orca
        cliente_id         : $input.cliente_id
        frtB2B             : $input.frtB2B
        frtB2C             : $input.frtB2C
        user_id            : $input.user_id
        margem             : $input.margem
        desconto           : $input.desconto
        vlr_cst_tot        : $input.vlr_cst_tot
        vlr_cst_tot_ipi    : $input.vlr_cst_tot_ipi
        vlr_cst_tot_imp    : $input.vlr_cst_tot_imp
        vlr_vnd_total      : $input.vlr_vnd_total
        vlr_vnd_tot_ipi    : $input.vlr_vnd_tot_ipi
        vlr_vnd_tot_imp    : $input.vlr_vnd_tot_imp
        vlr_vnd_tot_b2b    : $input.vlr_vnd_tot_b2b
        vlr_vnd_tot_b2b_b2c: $input.vlr_vnd_tot_b2b_b2c
      }
    } as $model
  }

  response = $model
  guid = "66DvHQOKLMNX2vsjVfsJa1Yvg_o"
}