table ControlePedido {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    // LEGADO (app antigo) — link para a tabela Pedido
    int pedido_id? {
      table = "Pedido"
    }
  
    // Novo vínculo: a Orca convertida em pedido (eh_pedido == true)
    int orca_id? {
      table = "Orca"
    }
  
    text codPedidoApp? filters=trim
    text codPedidoVenda? filters=trim
    text notaFiscal? filters=trim
    text transportadoraB2B? filters=trim
    text transportadoraB2C? filters=trim
    date? dataPrevisao?
    date? dataChegada?
    decimal freteB2BReal?
    decimal freteB2CReal?
  
    // Fluxo Kapazi (ordem lógica): envio → nº pedido fábrica → aprovação layout
    date? data_envio_fabrica?
  
    text num_pedido_fabrica? filters=trim
    date? data_aprovacao_layout?
    text num_pedido_venda? filters=trim
    text num_nf? filters=trim
  
    // Forma de acerto financeiro com a fábrica: boleto / acerto CC / Pix
    text forma_pagamento_fabrica? filters=trim
  
    // Desconto concedido pela fábrica (Kapazi) sobre o custo, em % (ex.: 10). 
    // Base: Σ vlr_cst_nota_unit × qtd. Só aumenta o lucro — não altera a venda.
    decimal desconto_kapazi_perc?
  
    text cod_rastreio? filters=trim
    int user_id? {
      table = "User"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree", field: [{name: "orca_id", op: "asc"}]}
  ]

  guid = "tVBuUVaSQpcg4r_nbSKpRZtLcj4"
}