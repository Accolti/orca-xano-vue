table Regra_Fiscal {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text nome? filters=trim
    bool tem_st?
    decimal mva_padrao?
    decimal aliq_st_interna?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "swPh35pavAX9YYvud4O3Iig1gzs"
}