// Aprova/recusa o desconto acima do limite livre do vendedor filho.
// Permissão: ancestral (pai/avô via vendedor_pai_id) ou admin_geral.
query orcamento_aprovar_desconto verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    bool aprovado?=true
  }

  stack {
    // Reforço: bloqueia quem foi desativado (o próprio ou um "pai") após o login
    function.run f_ativo_efetivo {
      input = {user_id: $auth.id}
    } as $ativoEfetivo
  
    precondition ($ativoEfetivo) {
      error_type = "accessdenied"
      error = "Conta inativa. Fale com o administrador."
    }
  
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
      output = ["id", "user_id"]
    } as $orca
  
    precondition ($orca != null) {
      error_type = "notfound"
      error = "Orçamento não encontrado."
    }
  
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role", "vendedor_pai_id"]
    } as $viewer
  
    db.get User {
      field_name = "id"
      field_value = $orca.user_id
      output = ["id", "role", "vendedor_pai_id"]
    } as $owner
  
    var $permitido {
      value = false
    }
  
    conditional {
      if ($viewer.role == "admin_geral") {
        var.update $permitido {
          value = true
        }
      }
    
      else {
        conditional {
          if (($owner.vendedor_pai_id != null) && ($owner.vendedor_pai_id > 0)) {
            conditional {
              if ($owner.vendedor_pai_id == $auth.id) {
                var.update $permitido {
                  value = true
                }
              }
            
              else {
                db.get User {
                  field_name = "id"
                  field_value = $owner.vendedor_pai_id
                  output = ["id", "role", "vendedor_pai_id"]
                } as $paiOwner
              
                conditional {
                  if (($paiOwner.role == "vendedor_master") && ($paiOwner.vendedor_pai_id == $auth.id)) {
                    var.update $permitido {
                      value = true
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  
    precondition ($permitido) {
      error_type = "accessdenied"
      error = "Apenas o pai/administrador pode aprovar o desconto."
    }
  
    var $statusDesc {
      value = "recusado"
    }
  
    conditional {
      if ($input.aprovado) {
        var.update $statusDesc {
          value = "aprovado"
        }
      }
    }
  
    var $notifTipo {
      value = "desconto_recusado"
    }
  
    conditional {
      if ($input.aprovado) {
        var.update $notifTipo {
          value = "desconto_aprovado"
        }
      }
    }
  
    db.add Notificacao {
      enforce_hidden_fields = false
      data = {
        created_at: "now"
        user_id   : $orca.user_id
        tipo      : $notifTipo
        orca_id   : $input.orca_id
        lida      : false
      }
    } as $notif_resultado
  
    db.edit Orca {
      field_name = "id"
      field_value = $input.orca_id
      enforce_hidden_fields = false
      data = {
        desconto_aprovado: $input.aprovado
        desconto_status  : $statusDesc
      }
    } as $editada
  }

  response = {
    id               : $editada.id
    desconto_aprovado: $editada.desconto_aprovado
  }

  tags = ["orcamento", "f3"]
  guid = "orcamento-aprovar-desconto-f3-0001"
}