table Contador {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int user_id? {
      table = "User"
    }
  
    text Descricao? filters=trim
    text Inicial? filters=trim
    int numero?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "_EIqnWlnFy80ggoK8LJETSPrV70"
}