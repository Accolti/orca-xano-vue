addon Pedido {
  input {
    int Pedido_id? {
      table = "Pedido"
    }
  }

  stack {
    db.query Pedido {
      where = $db.Pedido.id == $input.Pedido_id
      sort = {Pedido.created_at: "desc"}
      return = {type: "single"}
    }
  }

  guid = "AN-xcMIGuJCAe-DTuZRt8J1AZWw"
}