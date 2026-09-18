// Tabeça de usuários
table User {
  auth = true

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text name
    text name_first? filters=trim
    text name_last? filters=trim
    email? email
    password? password filters=min:8|minAlpha:1|minDigit:1 {
      visibility = "internal"
    }
  
    // logo ou foto do usuário
    image? logo?
  
    object google_oauth? {
      schema {
        text id? filters=trim
        text name? filters=trim
        email email?
      }
    }
  
    decimal frtB2B?
    decimal margem?
  
    // Quantidade de Dias para o orçamento
    int DiasVencimentoOrcamento?
  
    int organizacao_id? {
      table = "Organizacao"
    }
  
    text razao? filters=trim
    text fantasia? filters=trim
    text cnpj? filters=trim
    text ie? filters=trim
    text cpf? filters=trim
  
    // É pessoa jurídica
    bool isPJ?=true
  
    // UF do vendedor (destino da venda). Usado como uf_destino na precificação
    text uf? filters=trim|max:2
  
    int regime_id? {
      table = "Regime"
    }
  
    // Hierarquia/comissões (F3): admin_geral (dono/auditor), admin (conta/revenda) e
    // vendedor (subordinado). Contas existentes sem valor = admin (fallback no front).
    text role?
  
    int vendedor_pai_id? {
      table = "User"
    }
  
    decimal percentual_comissao?
    bool ativo?=true
  
    // Limites de desconto (%). Na raiz (admin/empresa) = padrão da equipe;
    // no vendedor = override (vazio = herda da empresa).
    decimal desconto_livre_perc?
  
    decimal desconto_max_perc?
  
    // Plano/serviços habilitados (slug). "plus" habilita o serviço de comissões;
    // ausente/"basico" = sem acesso (mostra mensagem nas telas de comissão).
    text plano?
  
    // Super admin do sistema: pode EXCLUIR DEFINITIVAMENTE qualquer orçamento
    // (cascata) pelo endpoint `orcamento_excluir_definitivo`.
    bool super_admin?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {type: "btree|unique", field: [{name: "email", op: "asc"}]}
  ]

  guid = "gOwtyLcCttptzbo07V9UO7ufkVE"
}