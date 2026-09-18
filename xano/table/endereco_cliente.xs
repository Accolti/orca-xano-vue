table Endereco_Cliente {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int cliente_id? {
      table = "Cliente"
    }
  
    enum Tipo?=Comercial {
      values = ["Comercial", "Residencial"]
    }
  
    text endereco? filters=trim
    text numero? filters=trim
    text complemento? filters=trim
    text cep? filters=trim
    text bairro? filters=trim
    text cidade? filters=trim
    text estado? filters=trim|max:2
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
  ]

  guid = "0c391fjAjc13cpeSrDo8NQlhldc"
}