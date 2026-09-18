// Incrementa a versão de materiais, produtos ou taxas de banco nas Configuracoes (dev tool, auth User).
// Ao alterar dados no catálogo (material, produto, variacao, taxa_banco), o operador bumpa a
// versão correspondente para forçar o app a rebaixar o cache localStorage.
query configuracoes_versao verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int configuracoes_id? {
      table = "Configuracoes"
    }
  
    enum campo?=versao_materiais {
      values = ["versao_materiais", "versao_produtos", "versao_taxas_banco"]
    }
  
    int delta?=1
  }

  stack {
    db.get Configuracoes {
      field_name = "id"
      field_value = $input.configuracoes_id
    } as $cfg
  
    var $atual {
      value = 0
    }
  
    conditional {
      if ($input.campo == "versao_materiais") {
        var.update $atual {
          value = $cfg.versao_materiais|first_notnull:0
        }
      }
    
      else {
        conditional {
          if ($input.campo == "versao_produtos") {
            var.update $atual {
              value = $cfg.versao_produtos|first_notnull:0
            }
          }
        
          else {
            var.update $atual {
              value = $cfg.versao_taxas_banco|first_notnull:0
            }
          }
        }
      }
    }
  
    var $novo {
      value = $atual + $input.delta
    }
  
    var $salvo {
      value = null
    }
  
    conditional {
      if ($input.campo == "versao_materiais") {
        db.edit Configuracoes {
          field_name = "id"
          field_value = $input.configuracoes_id
          enforce_hidden_fields = false
          data = {versao_materiais: $novo}
        } as $salvo
      }
    
      else {
        conditional {
          if ($input.campo == "versao_produtos") {
            db.edit Configuracoes {
              field_name = "id"
              field_value = $input.configuracoes_id
              enforce_hidden_fields = false
              data = {versao_produtos: $novo}
            } as $salvo
          }
        
          else {
            db.edit Configuracoes {
              field_name = "id"
              field_value = $input.configuracoes_id
              enforce_hidden_fields = false
              data = {versao_taxas_banco: $novo}
            } as $salvo
          }
        }
      }
    }
  }

  response = {
    configuracoes_id: $salvo.id
    campo           : $input.campo
    de              : $atual
    para            : $novo
    configuracoes   : $salvo
  }

  guid = "OrcaKap-configuracoes-versao"
}