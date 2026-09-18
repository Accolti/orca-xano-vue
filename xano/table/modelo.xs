table Modelo {
  auth = false

  schema {
    int id
    text Descricao? filters=trim
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int material_id? {
      table = "Material"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "2qRDOQKFaLs5G7BHDLiZF9s9XmQ"
}