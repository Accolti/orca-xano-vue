table Cor {
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

  view = {
    vw_cor_ordenada: {
      sort: {Descricao: "asc"}
      id  : "5b22d970-824e-4679-995a-192ead2ed458"
    }
  }

  guid = "sQd-bpWZr68WWNsHD7Lvciesl_0"
}