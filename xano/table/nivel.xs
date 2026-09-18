table Nivel {
  auth = false

  schema {
    int id
    text nome? filters=trim
    text Descricao? filters=trim
    int material_id? {
      table = "Material"
    }
  
    int linha_id? {
      table = "Linha"
    }
  
    int tipo_id? {
      table = "Tipo"
    }
  
    timestamp created_at?=now {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
  ]

  guid = "9hneOHSsDe9-OIvR0RgC3OI7OjA"
}