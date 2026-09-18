table Beneficio_Fiscal {
  auth = false

  schema {
    int id
    text descricao? filters=trim
    bool ativo?=true
    timestamp created_at?=now {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "AYksreKiPvAxsBiPaTMT-3Ke_AY"
}