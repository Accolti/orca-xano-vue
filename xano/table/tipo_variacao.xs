table Tipo_Variacao {
  auth = false

  schema {
    int id
    text Descricao? filters=trim
    timestamp created_at?=now {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "0daNu6hUE-FJ7iJcux-d3IMHjyE"
}