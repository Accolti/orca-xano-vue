query processar_pedidos_pagamentos verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    date? dt_ini?
    date? dt_fin?
    int user_id? {
      table = "User"
    }
  }

  stack {
    function.run fSumPedidosBoletos {
      input = {
        dt_ini : $input.dt_ini
        dt_fin : $input.dt_fin
        user_id: $input.user_id
      }
    } as $func1
  }

  response = $func1
  tags = ["pedidos", "pagamentos"]
  guid = "Xu1mkFQOgrI35A20dGHzsr3Dsfc"
}