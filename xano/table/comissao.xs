// Comissões (F3 Fase A): lançada quando um pedido do vendedor-filho fica 100% pago.
// valor = lucro_real (fórmula do relatório) × percentual_comissao do vendedor.
// status: calculada → paga (marcada pelo pai/admin_geral).
table Comissao {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    // Vendedor-filho que recebe a comissão (dono do orçamento)
    int user_id? {
      table = "User"
    }
  
    int orca_id? {
      table = "Orca"
    }
  
    // % negociado pelo pai no cadastro do vendedor
    decimal percentual?
  
    // Base do cálculo (lucro_real na Fase A; valor de venda vnd_tot na Fase A.2)
    decimal lucro_real_base?
  
    // Base usada na Fase A.2 (venda vnd_tot)
    decimal base_valor?
  
    // Papel do recebedor: vendedor (ponta) | override (Vendedor Master)
    text tipo?=vendedor filters=trim
  
    // Valor da comissão (base × percentual / 100)
    decimal valor?
  
    text status?=calculada filters=trim
    date? data_pagamento?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "orca_id", op: "asc"}]}
    {type: "btree", field: [{name: "user_id", op: "asc"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "comissao-f3-0001"
}