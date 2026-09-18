table Telefone_User {
  auth = false

  schema {
    int id
    int? user_id {
      table = "User"
    }
  
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text telefone? filters=trim
    enum tipo_telefone? {
      values = [
        "Celular Particular"
        "Celular Comercial"
        "Fixo Particular"
        "Fixo Comercial"
        "Whatsapp"
      ]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "JYodud8MckroUvfkmSNz-cNFPk8"
}