table Linha {
  auth = false

  schema {
    int id
    text nome? filters=trim
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

  guid = "xS3ETLkB2xcG0pRCqeE7FWMU4Lc"
}