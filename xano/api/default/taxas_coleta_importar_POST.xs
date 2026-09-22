// Importa as taxas coletadas pelo cron (Node) para a tabela GLOBAL (user_id = 0).
// Substitui APENAS as linhas de origem "scrape" do par provedor+canal — nunca toca
// nas manuais. Atualiza Provedor.ultima_coleta e grava Taxa_Coleta_Log.
// Autenticação por token de serviço (env `coleta_secret`). Endpoint público + token.
query taxas_coleta_importar verb=POST {
  api_group = "Default"

  input {
    text token? filters=trim
  
    int provedor_id? {
      table = "Provedor"
    }
  
    text canal? filters=trim
    json taxas?
    bool sucesso?=true
    text mensagem? filters=trim
  
    // true = substitui TAMBÉM as taxas manuais do par provedor+canal (uso pontual/admin)
    bool substituir_manual?=false
  }

  stack {
    precondition ($input.token != null && $input.token != "" && $input.token == $env.workspace.coleta_secret) {
      error_type = "accessdenied"
      error = "Token inválido."
    }
  
    precondition ($input.provedor_id != null && $input.provedor_id > 0) {
      error_type = "badrequest"
      error = "Informe provedor_id."
    }
  
    precondition (($input.canal == "cartao_link") || ($input.canal == "cartao_celular") || ($input.canal == "cartao_pos")) {
      error_type = "badrequest"
      error = "Canal inválido (use cartao_link, cartao_celular ou cartao_pos)."
    }
  
    // Remove as taxas anteriores do par provedor+canal.
    // Padrão: somente origem = "scrape" (nunca toca nas manuais).
    // Com substituir_manual = true: remove todas (scrape + manual).
    db.query Taxa_Banco {
      where = $db.Taxa_Banco.provedor_id == $input.provedor_id && $db.Taxa_Banco.canal == $input.canal && ($input.substituir_manual || $db.Taxa_Banco.origem == "scrape")
      return = {type: "list"}
      output = ["id"]
    } as $antigas
  
    foreach ($antigas) {
      each as $a {
        db.del Taxa_Banco {
          field_name = "id"
          field_value = $a.id
        }
      }
    }
  
    // Insere as novas (só quando a coleta deu certo)
    var $inseridas {
      value = 0
    }
  
    conditional {
      if ($input.sucesso == true && $input.taxas != null) {
        foreach ($input.taxas) {
          each as $t {
            conditional {
              if (($t.parcelas != null) && ($t.parcelas > 0) && ($t.cc_taxa != null)) {
                db.add Taxa_Banco {
                  enforce_hidden_fields = false
                  data = {
                    user_id      : 0
                    provedor_id  : $input.provedor_id
                    parcelas     : $t.parcelas
                    cc_taxa      : $t.cc_taxa
                    canal        : $input.canal
                    ativo        : true
                    origem       : "scrape"
                    atualizado_em: "now"
                    created_at   : "now"
                  }
                } as $nova
              
                var.update $inseridas {
                  value = $inseridas + 1
                }
              }
            }
          }
        }
      }
    }
  
    // Marca a última coleta do provedor
    db.edit Provedor {
      field_name = "id"
      field_value = $input.provedor_id
      enforce_hidden_fields = false
      data = {ultima_coleta: "now"}
    } as $prov
  
    // Auditoria
    db.add Taxa_Coleta_Log {
      enforce_hidden_fields = false
      data = {
        created_at : "now"
        provedor_id: $input.provedor_id
        canal      : $input.canal
        sucesso    : $input.sucesso
        mensagem   : $input.mensagem
        qtd_taxas  : $inseridas
      }
    } as $log
  }

  response = {
    ok        : $input.sucesso
    removidas : $antigas|count
    inseridas : $inseridas
  }

  tags = ["novo-sis", "taxas", "coleta"]
  guid = "taxas-coleta-importar-0001"
}
