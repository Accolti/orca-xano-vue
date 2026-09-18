table Telefone_Cliente {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int cliente_id? {
      table = "Cliente"
    }
  
    int tipo_telefone_id? {
      table = "Tipo_Telefone"
    }
  
    text telefone? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
  ]

  guid = "Mwc3TAZTRPsIhOCQjUp7PIYwXls"
}