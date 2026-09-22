// Configurações para atualização de LocalStorage PINEA
table Configuracoes {
  auth = false

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    // versão dos materiais mae. Quando alterada a API que verifica mudança roda e os materias sao baixados novamente (Materiais, Linha, Tipo, Nivel, Borda)
    int versao_materiais?
  
    // Aqui são todos os produtos de tabela de Produtos e Variacao. Então quando hover alterações nestas tabelas deve ser mudado a versão
    int versao_produtos?
  
    // Versão das taxas de banco (Taxa_Banco). Quando alterada, o app rebaixa a tabela de taxas e recalcula as condições de pagamento
    int versao_taxas_banco?
  
    // Data da última atualização automática das taxas (cron) — usada no banner do app
    timestamp taxas_atualizado_em?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]

  guid = "b-I0ynns6s1ZVSHBBjNFWoet-Jc"
}