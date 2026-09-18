query pedido verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Pedido {
      return = {type: "list"}
    } as $model
  }

  response = $model
  guid = "UhBg6CEojPwHPXyrBUJSXJ6-CT4"
}