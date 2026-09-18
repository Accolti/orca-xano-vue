// Orçamentos Gerados
table Gerados {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int orca_id? {
      table = "Orca"
    }
  
    // Nome do Arquivo
    text nome? filters=trim
  
    image? imagem?
    text url? filters=trim
    enum tipo? {
      values = ["pdf", "whats"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  tags = ["orcamento", "pdf"]
  guid = "AwrqHnMimgjAeCcoS9E9qlMv1xo"
}