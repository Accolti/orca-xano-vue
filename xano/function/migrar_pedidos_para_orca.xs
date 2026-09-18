// Migração one-off: converte os Pedidos existentes em Orcas marcadas como pedido.
// Casa o Pedido com a Orca pela FK legada Orca.pedido_id == Pedido.id (NÃO por cod_orca,
// que não é indexado e ficou vazio/divergente em registros antigos).
// Grava eh_pedido = true, mapeia o status antigo para o novo enum e registra na auditoria.
// Idempotente: pula Orcas já migradas (eh_pedido == true). Tudo dentro de db.transaction.
// Rodar UMA VEZ no dashboard (Code Block) antes de dropar as tabelas legadas.
function MigrarPedidosParaOrca {
  input {
  }

  stack {
    db.query Pedido {
      return = {type: "list"}
    } as $pedidos
  
    var $migrados {
      value = 0
    }
  
    var $sem_orca {
      value = 0
    }
  
    db.transaction {
      stack {
        foreach ($pedidos) {
          each as $ped {
            db.query Orca {
              where = $db.Orca.pedido_id == $ped.id
              return = {type: "single"}
            } as $orca
          
            conditional {
              if (($orca|count) == 0) {
                debug.stop {
                  value = "orca_sem_id"|concat:$ped.id:"Problema"
                }
              
                var.update $sem_orca {
                  value = $sem_orca|add:1
                }
              }
            }
          
            conditional {
              if (($orca.pedido_id > 1)) {
                var $status_novo {
                  value = "AGUARDANDO_FATURAMENTO"
                }
              
                !debug.stop {
                  value = $ped.status
                }
              
                conditional {
                  if ($ped.status == "FATURADO") {
                    var.update $status_novo {
                      value = "FATURADO"
                    }
                  }
                }
              
                conditional {
                  if (($ped.status|to_upper) == "ENTREGUE") {
                    var.update $status_novo {
                      value = "ENTREGUE"
                    }
                  }
                }
              
                !debug.stop {
                  value = $status_novo
                }
              
                conditional {
                  if ($ped.status == "CANCELADO") {
                    var.update $status_novo {
                      value = "CANCELADO"
                    }
                  }
                }
              
                db.edit Orca {
                  field_name = "id"
                  field_value = $orca.id
                  enforce_hidden_fields = false
                  data = {status: $status_novo, eh_pedido: true}
                } as $Orca_editada
              
                db.add Orca_Status_Log {
                  enforce_hidden_fields = false
                  data = {
                    created_at     : "now"
                    orca_id        : $orca.id
                    status         : $status_novo
                    status_anterior: $orca.status
                    user_id        : $orca.user_id
                    motivo         : "Migrado de Pedido (legado)"
                  }
                } as $Log_1
              
                var.update $migrados {
                  value = $migrados|add:1
                }
              
                !debug.stop {
                  value = $migrados
                }
              }
            }
          }
        }
      }
    }
  }

  response = {migrados: $migrados, sem_orca: $sem_orca}
  tags = ["orcamento", "migracao"]
  guid = "migrar-pedidos-para-orca-0001"
}