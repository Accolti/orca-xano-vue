// Log das coletas automáticas de taxas (cron Node/GitHub Actions).
table Taxa_Coleta_Log {
  auth = false

  schema {
    int id
  
    int provedor_id? {
      table = "Provedor"
    }
  
    // Canal coletado: cartao_link | cartao_celular | cartao_pos
    text canal? filters=trim
  
    bool sucesso?=true
    text mensagem? filters=trim
  
    // Quantidade de taxas gravadas
    int qtd_taxas?
  
    timestamp created_at?=now {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  tags = ["novo-sis", "taxas", "coleta"]
  guid = "taxa-coleta-log-0001"
}
