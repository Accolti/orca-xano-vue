table Boleto {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    date? vencimento?
    date? pagamento?
    decimal valor?
    int forma_pagamento_id?=1 {
      table = "Forma_Pagamento"
    }
  
    text obs? filters=trim
    int pedido_id? {
      table = "Pedido"
    }
  
    int orca_id? {
      table = "Orca"
    }
  
    int user_id? {
      table = "User"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "4G-ka4LLAeee6wiPxG9F02nU3AY"
}