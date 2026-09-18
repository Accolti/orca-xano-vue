table telefone_user {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
  ]

  guid = "BlWs_65qes6L_k10VOb1gJP0Hdc"
}