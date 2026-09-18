// Exclusão DEFINITIVA em cascata de um orçamento: apaga todas as tabelas que
// referenciam a Orca (item, Boleto, Comissao, ControlePedido, Desconto_Kapazi_Log,
// Gerados, Notificacao, Orca_Status_Log), o legado (Pedido/item_ped via pedido_id)
// e a própria Orca — em transação.
function "Orcamento/f_excluir_orcamento" {
  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
      output = ["id", "pedido_id"]
    } as $orcaDel
  
    db.transaction {
      stack {
        db.query item {
          where = $db.item.orca_id == $input.orca_id
          return = {type: "list"}
          output = ["id"]
        } as $itens
      
        foreach ($itens) {
          each as $r {
            db.del item {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      
        db.query Boleto {
          where = $db.Boleto.orca_id == $input.orca_id
          return = {type: "list"}
          output = ["id"]
        } as $boletos
      
        foreach ($boletos) {
          each as $r {
            db.del Boleto {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      
        db.query Comissao {
          where = $db.Comissao.orca_id == $input.orca_id
          return = {type: "list"}
          output = ["id"]
        } as $comissoes
      
        foreach ($comissoes) {
          each as $r {
            db.del Comissao {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      
        db.query ControlePedido {
          where = $db.ControlePedido.orca_id == $input.orca_id
          return = {type: "list"}
          output = ["id"]
        } as $controles
      
        foreach ($controles) {
          each as $r {
            db.del ControlePedido {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      
        db.query Desconto_Kapazi_Log {
          where = $db.Desconto_Kapazi_Log.orca_id == $input.orca_id
          return = {type: "list"}
          output = ["id"]
        } as $logs
      
        foreach ($logs) {
          each as $r {
            db.del Desconto_Kapazi_Log {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      
        db.query Gerados {
          where = $db.Gerados.orca_id == $input.orca_id
          return = {type: "list"}
          output = ["id"]
        } as $gerados
      
        foreach ($gerados) {
          each as $r {
            db.del Gerados {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      
        db.query Notificacao {
          where = $db.Notificacao.orca_id == $input.orca_id
          return = {type: "list"}
          output = ["id"]
        } as $notificacoes
      
        foreach ($notificacoes) {
          each as $r {
            db.del Notificacao {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      
        db.query Orca_Status_Log {
          where = $db.Orca_Status_Log.orca_id == $input.orca_id
          return = {type: "list"}
          output = ["id"]
        } as $logsStatus
      
        foreach ($logsStatus) {
          each as $r {
            db.del Orca_Status_Log {
              field_name = "id"
              field_value = $r.id
            }
          }
        }
      
        // Legado: Pedido/item_ped (se a Orca tiver pedido_id)
        conditional {
          if (($orcaDel != null) && ($orcaDel.pedido_id != null) && ($orcaDel.pedido_id > 0)) {
            db.query item_ped {
              where = $db.item_ped.pedido_id == $orcaDel.pedido_id
              return = {type: "list"}
              output = ["id"]
            } as $itensPed
          
            foreach ($itensPed) {
              each as $r {
                db.del item_ped {
                  field_name = "id"
                  field_value = $r.id
                }
              }
            }
          
            db.del Pedido {
              field_name = "id"
              field_value = $orcaDel.pedido_id
            }
          }
        }
      
        db.del Orca {
          field_name = "id"
          field_value = $input.orca_id
        }
      }
    }
  }

  response = {ok: true}
  tags = ["orcamento"]
  guid = "R_-FvT6Tt2lZ-VAmz3_Le-5xwJ8"
}