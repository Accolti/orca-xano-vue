table Regime {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text descricao? filters=trim
  
    // Slug do regime para precificação (MEI, SIMPLES, LUCRO_REAL, LUCRO_PRESUMIDO)
    text slug? filters=trim
  
    bool ativo?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "naBszaeUKdw7_HtAPOt6Gt1KHA8"
}