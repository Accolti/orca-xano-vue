// Faixas de comissão por empresa (admin/revenda) — comissão escalonada por markup
// efetivo. O % total da faixa é o liberado ao Vendedor Master; o override é o
// remanescente após a ponta. Sem faixas → regime fixo (Fase A).
table Faixa_Comissao {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    // Empresa dona da configuração (admin/revenda; admin_geral pode gerenciar)
    int user_id? {
      table = "User"
    }
  
    // Faixa de markup efetivo (ex.: 50 a 69)
    decimal faixa_min?
  
    decimal faixa_max?
  
    // Total de comissão liberado nessa faixa (empresa → Master), em %
    decimal comissao_total_perc?
  
    int ordem?
    bool ativo?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "user_id", op: "asc"}]}
  ]

  guid = "faixa-comissao-f3-0001"
}