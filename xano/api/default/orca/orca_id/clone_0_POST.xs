// *** bAlterarMargItem *** deve ser true quando há a necesseidade de recalculo de margem e valores na tabele de itens
query "orca/{orca_id}/clone_0" verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? filters=min:1
    int cliente_id? {
      table = "Cliente"
    }
  
    text cod_orca? filters=trim
    timestamp created_at?=now {
      visibility = "internal"
    }
  }

  stack {
    function.run orca_change {
      input = {
        orca_id        : $input.orca_id
        cliente_id     : $input.cliente_id
        frtB2B         : $input.frtB2B
        frtB2C         : $input.frtB2C
        validade       : $input.validade
        user_id        : $input.user_id
        margem         : $input.margem
        desconto       : $input.desconto
        bAlteraMargItem: $input.bAlteraMargItem
      }
    } as $func_1
  }

  response = $func_1
  guid = "vGEEj2K89GjlOF1JbpGaiixk9f8"
}