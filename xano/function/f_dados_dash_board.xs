function fDadosDashBoard {
  input {
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.query Orca {
      where = $db.Orca.user_id == $input.user_id && $db.Orca.eh_pedido != true
      return = {type: "count"}
    } as $Orca_1
  
    db.query Orca {
      where = $db.Orca.user_id == $input.user_id && $db.Orca.eh_pedido == true
      return = {type: "count"}
    } as $Pedido_1
  
    function.run fBoleto_Vencido {
      input = {user_id: $input.user_id, Tipo: "Count"}
    } as $Boleto_Vencido
  
    function.run fBoleto_A_Vencer {
      input = {user_id: $input.user_id, Tipo: "Count", qtdDias: 5}
    } as $Boleto_A_Vencer
  
    function.run fBoleto_Pago {
      input = {user_id: $input.user_id, Tipo: "Count"}
    } as $Boleto_Pago
  }

  response = {
    Orcamento      : $Orca_1
    Pedido         : $Pedido_1
    Boleto_Vencido : $Boleto_Vencido
    Boleto_Pago    : $Boleto_Pago
    Boleto_A_Vencer: $Boleto_A_Vencer
  }

  guid = "t2XMvfNXZbdwD8cl8SV9ftJNdMc"
}