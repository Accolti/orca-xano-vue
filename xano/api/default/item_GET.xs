// Query all item records
query item verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query item {
      return = {type: "list"}
    } as $item
  }

  response = $item
  guid = "4Eba2vGas1KXeJJRf_TqLjnAuJk"
}