// Notificações do app (N2). Atualmente: aprovações/recusas de desconto.
// Escrita por orcamento_recalcular (pendente → pai) e orcamento_aprovar_desconto
// (aprovado/recusado → dono filho). Expande depois p/ outros eventos.
table Notificacao {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    // Destinatário
    int user_id? {
      table = "User"
    }
  
    // desconto_pendente | desconto_aprovado | desconto_recusado
    text tipo? filters=trim
  
    int orca_id? {
      table = "Orca"
    }
  
    bool lida?
    timestamp data_leitura? {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {
      type : "btree"
      field: [
        {name: "user_id", op: "asc"}
        {name: "created_at", op: "desc"}
      ]
    }
  ]

  guid = "notificacao-f3-0001"
}