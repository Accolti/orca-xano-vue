table Unidade {
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

  guid = "fwtsNcccVR25LkkmoGeHYLt_q1E"
}