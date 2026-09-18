table TestWithDate {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    date? initial?
    text telefone? filters=trim
    enum tipo? {
      values = ["whats", "cel"]
    }
  
    int cliente_id? {
      table = "Cliente"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "8M-_XVaVebBnmNLw8-s9wW1h6-4"
}