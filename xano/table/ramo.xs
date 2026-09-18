table Ramo {
  auth = false

  schema {
    int id
    text descricao? filters=trim
    timestamp created_at?=now {
      visibility = "private"
    }
  
    bool ativo?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "lkJL__9d8PNAngiZpSkbi7_nt-0"
}