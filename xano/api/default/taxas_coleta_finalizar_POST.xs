// Chamado pelo cron (Node) ao final de uma coleta que ALTEROU alguma taxa:
// incrementa `versao_taxas_banco` (invalida o cache dos clientes) e grava
// `taxas_atualizado_em` (usado pelo banner do app).
// Autenticação por token de serviço (env `coleta_secret`). Endpoint público + token.
query taxas_coleta_finalizar verb=POST {
  api_group = "Default"

  input {
    text token? filters=trim
  }

  stack {
    precondition ($input.token != null && $input.token != "" && $input.token == $env.workspace.coleta_secret) {
      error_type = "accessdenied"
      error = "Token inválido."
    }
  
    db.query Configuracoes {
      return = {type: "single"}
      output = ["id", "versao_taxas_banco"]
    } as $cfg
  
    precondition ($cfg != null) {
      error_type = "notfound"
      error = "Configuracoes não encontrada."
    }
  
    var $novo {
      value = ($cfg.versao_taxas_banco|first_notnull:0) + 1
    }
  
    db.edit Configuracoes {
      field_name = "id"
      field_value = $cfg.id
      enforce_hidden_fields = false
      data = {
        versao_taxas_banco : $novo
        taxas_atualizado_em: "now"
      }
    } as $salvo
  }

  response = {
    versao_taxas_banco : $novo
    taxas_atualizado_em: $salvo.taxas_atualizado_em
  }

  tags = ["novo-sis", "taxas", "coleta"]
  guid = "taxas-coleta-finalizar-0001"
}
