addon Boleto_of_Pedido {
  input {
    int pedido_id? {
      table = "Pedido"
    }
  }

  stack {
    db.query Boleto {
      where = $db.Boleto.pedido_id == $input.pedido_id
      return = {type: "list"}
    }
  }

  guid = "2z_fDJLu3L2h2tFwZ3_TjJDkeas"
}