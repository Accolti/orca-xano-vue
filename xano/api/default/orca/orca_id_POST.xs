// *** bAlterarMargItem *** deve ser true quando há a necesseidade de recalculo de margem e valores na tabele de itens
query "orca/{orca_id}" verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? filters=min:1
    dblink {
      table = "Orca"
      override = {
        frtB2B  : {hidden: true}
        frtB2C  : {hidden: true}
        cod_orca: {hidden: true}
        desconto: {hidden: true}
      }
    }
  
    // Desconto
    decimal? desc?
  
    decimal? freteB2C?
    decimal? freteB2B?
    bool bAlteraMargItem?
  }

  stack {
    function.run orca_change {
      input = {
        orca_id        : $input.orca_id
        cliente_id     : $input.cliente_id
        validade       : $input.validade
        user_id        : $input.user_id
        margem         : $input.margem
        cst_tot        : $input.cst_tot
        luc_tot        : $input.luc_tot
        vnd_tot        : $input.vnd_tot
        vnd_B2B_tot    : $input.vnd_B2B_tot
        vnd_B2B_B2C_tot: $input.vnd_B2B_B2C_tot
        bAlteraMargItem: $input.bAlteraMargItem
        freteB2C       : $input.freteB2C
        desc           : $input.desc
        freteB2B       : $input.freteB2B
      }
    } as $func_1
  }

  response = $func_1
  guid = "iT3uB3sk7IwUFHlD3gVtS_OP4Jc"
}