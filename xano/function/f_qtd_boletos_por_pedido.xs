function fQtdBoletosPorPedido {
  input {
    int pedido_id? {
      table = "Pedido"
    }
  }

  stack {
    db.query Boleto {
      where = $db.Boleto.pedido_id == $input.pedido_id
      return = {type: "count"}
    } as $Boleto_1
  }

  response = $Boleto_1
  guid = "698vrPDuJxW24aG3U_StW2kub-Y"
}