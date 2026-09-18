// Para detalhamento de produtos  ela é tabela mãe. 
table Detalhe {
  auth = false

  schema {
    int id
    text Descricao? filters=trim
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int[] produto_id? {
      table = "Produto"
    }
  
    text Obs? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "9AMGzyL9nOSN4yrqX0xfNprmejk"
}