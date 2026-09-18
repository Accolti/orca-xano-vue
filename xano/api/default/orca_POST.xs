// Add Orca record
query orca verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Orca"
      override = {margem: {hidden: false}, cod_orca: {hidden: false}}
    }
  }

  stack {
    function.run post_orca {
      input = {
        cod_orca  : $input.cod_orca
        cliente_id: $input.cliente_id
        frtB2B    : $input.frtB2B
        frtB2C    : $input.frtB2C
        validade  : $input.validade
        user_id   : $input.user_id
        margem    : $input.margem
      }
    } as $func_1
  }

  response = $func_1
  guid = "6HNpcolpjeYh9g_-9LOkBVm3swE"
}