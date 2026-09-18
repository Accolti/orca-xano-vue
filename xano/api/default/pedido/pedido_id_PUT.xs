query "pedido/{pedido_id}" verb=PUT {
  api_group = "Default"

  input {
    int pedido_id? filters=min:1
    dblink {
      table = "Pedido"
    }
  }

  stack {
    db.edit Pedido {
      field_name = "id"
      field_value = $input.pedido_id
      enforce_hidden_fields = false
      data = {
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
  guid = "bqi2a-f7XCgXcnnx0lWIvjkiXX4"
}