// Retorna `false` se o usuário OU qualquer ancestral (vendedor_pai_id) estiver
// inativo (`ativo=false`). Desativar um "pai" bloqueia toda a árvore; reativar
// restaura (não mexe nos flags individuais). admin_geral também é avaliado.
//
// OTIMIZAÇÃO: caminhada pontual na cadeia (db.get por PK) em vez de carregar a
// tabela User inteira + lambda. Limitada a 5 níveis (admin → master → vendedor).
function f_ativo_efetivo {
  input {
    int user_id? {
      table = "User"
    }
  }

  stack {
    var $ok {
      value = true
    }
  
    db.get User {
      field_name = "id"
      field_value = $input.user_id
      output = ["id", "vendedor_pai_id", "ativo"]
    } as $u0
  
    conditional {
      if ($u0 == null || $u0.ativo == false) {
        var.update $ok {
          value = false
        }
      }
    }
  
    var $pai {
      value = $u0.vendedor_pai_id
    }
  
    var $guard {
      value = 0
    }
  
    while (($pai != null) && ($pai > 0) && ($guard < 5)) {
      each {
        db.get User {
          field_name = "id"
          field_value = $pai
          output = ["id", "vendedor_pai_id", "ativo"]
        } as $up
      
        conditional {
          if ($up == null || $up.ativo == false) {
            var.update $ok {
              value = false
            }
          }
        }
      
        conditional {
          if ($up == null) {
            var.update $pai {
              value = 0
            }
          }
        
          else {
            var.update $pai {
              value = $up.vendedor_pai_id
            }
          }
        }
      
        var.update $guard {
          value = $guard + 1
        }
      }
    }
  }

  response = $ok
  tags = ["usuario", "ativo", "f3"]
  guid = "f-ativo-efetivo-0001"
}
