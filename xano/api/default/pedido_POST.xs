query pedido verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Pedido"
    }
  }

  stack {
    function.run pedido_func {
      input = {pedido__: $input.pedido__}
    } as $func_1
  }

  response = $func_1
  guid = "9_wcWrzgA84mmlnWU37BAso5wQg"
}