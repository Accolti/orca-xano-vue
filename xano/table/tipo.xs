table Tipo {
  auth = false

  schema {
    int id
    text nome? filters=trim
    int material_id? {
      table = "Material"
    }
  
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int order?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      name : "Tipo_Search"
      lang : "portuguese"
      type : "search"
      field: [{name: "nome", op: "A"}]
    }
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {
      type : "btree|unique"
      field: [{name: "nome", op: "asc"}, {name: "material_id", op: "asc"}]
    }
  ]

  guid = "xprRvGhea9_-H5UwRe1wCwkzo5k"
}