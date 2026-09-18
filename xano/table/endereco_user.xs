// Endereço do usuario
table endereco_user {
  auth = false

  schema {
    int id
    int user_id? {
      table = "User"
    }
  
    timestamp created_at?=now {
      visibility = "private"
    }
  
    // Se é comercial, Residencial
    enum tipoendereco? {
      values = ["Residencial", "Comercial"]
    }
  
    text endereco? filters=trim
    text numero? filters=trim
    text complemento? filters=trim
    text cep? filters=trim
    text bairro? filters=trim
    text cidade? filters=trim
    text estado? filters=trim|max:2|upper|alphaOk
  
    // Vai dizer qual é o endereço preferencial do usuário
    bool preferencial?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "k-Ww0Ox4fzBN5tIBDnfgI0qmyos"
}