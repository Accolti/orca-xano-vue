table Pedido {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text num_ped? filters=trim
    text cod_orca? filters=trim
    int cliente_id? {
      table = "Cliente"
    }
  
    decimal frtB2B?
    decimal frtB2C?
    int user_id? {
      table = "User"
    }
  
    decimal margem?
  
    // Desconto sobre o valor total do pedido
    decimal desconto?
  
    decimal vlr_cst_tot?
    decimal vlr_cst_tot_ipi?
    decimal vlr_cst_tot_imp?
    decimal vlr_vnd_total?
    decimal vlr_vnd_tot_ipi?
    decimal vlr_vnd_tot_imp?
    decimal vlr_vnd_tot_b2b?
    decimal vlr_vnd_tot_b2b_b2c?
    text observacao? filters=trim
    enum status?=AGUARDANDO_FATURAMENTO {
      values = ["AGUARDANDO_FATURAMENTO", "FATURADO", "ENTREGUE", "CANCELADO"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "N30Q3Is69s0S5B42i2riDVPdf48"
}