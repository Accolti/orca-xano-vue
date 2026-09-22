table Aliquotas_icms {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text uf? filters=trim
    decimal aliquota_modal?
    text regiao? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree", field: [{name: "uf", op: "asc"}]}
  ]

  guid = "fECDYtG29qmA6O-J9L0lVL9wq_Q"
}