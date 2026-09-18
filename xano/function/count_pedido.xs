function count_Pedido {
  input {
  }

  stack {
    db.query Pedido {
      return = {type: "count"}
    } as $Pedido1
  }

  response = $Pedido1
  guid = "j1iXRUVXFzBG1JQvMUrthTaa8HM"
}