// Exemplo ADK é um tipo de acessório
table Acessorio {
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

  guid = "jKWwBr8nKu3f5o9Gyyrl_3b8rQA"
}