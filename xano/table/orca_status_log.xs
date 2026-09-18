// Histórico de status do orçamento — auditoria (quem, quando, de onde para onde, motivo).
table Orca_Status_Log {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int orca_id? {
      table = "Orca"
    }
  
    // Status novo (destino) da transição
    text status? filters=trim
  
    // Status de onde saiu (nulo no primeiro registro)
    text status_anterior? filters=trim
  
    int user_id? {
      table = "User"
    }
  
    // Motivo/observação opcional (RECUSADO/CANCELADO e reversões)
    text motivo? filters=trim
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [
        {name: "orca_id", op: "asc"}
        {name: "created_at", op: "desc"}
      ]
    }
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
  ]

  guid = "orca-status-log-0001"
}