// Query all cliente records
query cliente_user verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Cliente {
      where = $db.Cliente.user_id ==? $auth.id
      return = {type: "list"}
    } as $cliente
  
    !db.query Cliente {
      return = {type: "list"}
    } as $cliente
  }

  response = $cliente
  guid = "Iua19RKUHCcF8EwxLDufsiM6ESw"
}