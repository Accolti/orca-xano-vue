table Orca {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text cod_orca? filters=trim
    int cliente_id? {
      table = "Cliente"
    }
  
    decimal frtB2B?
    decimal frtB2C?
    date? validade?
    int user_id? {
      table = "User"
    }
  
    decimal margem?
    decimal cst_tot?
    decimal luc_tot?
    decimal vnd_tot?
    decimal vnd_B2B_tot?
    decimal vnd_B2B_B2C_tot?
  
    // Desconto sobre o valor total do pedido
    decimal desconto?
  
    // Desconto do vendedor filho aprovado pelo pai (false = pendente)
    bool desconto_aprovado?
  
    // Estado do desconto do filho: aprovado | pendente | recusado
    text desconto_status? filters=trim
  
    // Observações gerais do orçamento (exibidas no final do PDF)
    text observacao? filters=trim
  
    // Condições de pagamento salvas (Pix/Boleto etc.) — exibidas no PDF e WhatsApp
    text condicoes_pagamento? filters=trim
  
    // Estado do seletor de condições (JSON): metodos, mesclar, trazerTodasParcelas,
    // descontoPixPercentual, provedor_id/provedor, parcelas, repassarTaxas, aba.
    text condicoes_pagamento_params? filters=trim
  
    // Serviço de mão de obra — soma apenas no Total Geral (não altera lucro/margem)
    decimal mao_de_obra?
  
    // LEGADO (migração): FK para a antiga tabela Pedido. Remover após MigrarPedidosParaOrca.
    int pedido_id? {
      table = "Pedido"
    }
  
    enum status?=RASCUNHO {
      values = [
        "RASCUNHO"
        "ENVIADO"
        "AGUARDANDO_RETORNO"
        "APROVADO"
        "AGUARDANDO_FATURAMENTO"
        "FATURADO"
        "ENTREGUE"
        "RECUSADO"
        "CANCELADO"
      ]
    }
  
    // true quando o orçamento foi convertido em pedido (congela edição)
    bool eh_pedido?
  
    int regime_id? {
      table = "Regime"
    }
  
    text uf_origem?=PR filters=trim|upper
    text uf_destino?=SP filters=trim|upper
  
    // O percentual de markup/margem inserido pelo usuário na simulação antes de descontos.
    decimal markup_alvo?
  
    // Preço bruto (antes do desconto) — Σ custo_entrada × (1 + markup_alvo/100). Auditoria.
    decimal venda_bruta_tot?
  
    // Margem efetiva real após desconto/frete/mão de obra — (vnd_tot/cst_tot − 1) × 100. Auditoria.
    decimal markup_efetivo?
  
    text motivo_recusa? filters=trim
  
    // Soma do ST de todos os itens da item
    decimal vlr_st_tot?
  
    decimal vlr_ipi_tot?
    decimal valor_difal_tot?
    decimal vlr_credito_icms_tot?
    decimal vlr_custo_fiscal_tot?
  
    // Quantidade de linhas/itens presentes no orçamento.
    int total_itens?
  
    timestamp? data_aprovacao?
    timestamp? data_envio?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {
      type : "btree|unique"
      field: [{name: "user_id", op: "asc"}, {name: "cod_orca", op: "asc"}]
    }
  ]

  guid = "VeHsBzinm9Mwfe34M2UfGjVcNgI"
}