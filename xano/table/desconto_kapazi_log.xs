// Log append-only das mudanças do desconto Kapazi (percentual concedido pela fábrica).
// Gravado por controle_pedido_salvar quando o % muda; consumido só pelos relatórios
// (lucro/margem real "as of"), o campo ControlePedido.desconto_kapazi_perc segue vivo.
table Desconto_Kapazi_Log {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    int orca_id? {
      table = "Orca"
    }
  
    // Desconto anterior e novo (em %)
    decimal desconto_anterior?
  
    decimal desconto_novo?
  
    // Valor do desconto em R$ na data do log (base = Σ item.vlr_cst_nota_unit × qtd)
    decimal valor_desconto_rs?
  
    // Frete efetivo em uso no momento do log (ControlePedido.freteB2BReal ou Orca.frtB2B)
    decimal frete_efetivo_rs?
  
    // Quem gravou
    int user_id? {
      table = "User"
    }
  
    // Motivo/observação opcional (ex.: negociação com a fábrica)
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

  guid = "desconto-kapazi-log-0001"
}