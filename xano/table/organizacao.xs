// Empresa produtora. Como exemplo a Kapazi que tem vários cooperados a ela.
table Organizacao {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text nome? filters=trim
    text cnpj? filters=trim
    text IE? filters=trim
  
    // UF da organização fornecedora (ex.: "PR" da Kapazi). Usado como uf_origem na precificação
    text uf? filters=trim|max:2
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "KNO4E721EuUxAogC65NC-ZjSsgA"
}