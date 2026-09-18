// Gera o próximo número de orçamento do usuário (Contador por user_id, prefixo ORC).
// Leitura + criação + incremento dentro de db.transaction; o índice único (user_id,
// cod_orca) da Orca garante que códigos duplicados não sejam criados em concorrência.
function Novo_Numero_Orcamento {
  input {
    int id_do_Usuario?
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $input.id_do_Usuario
    } as $User_1
  
    var $newOrca {
      value = ""
    }
  
    var $contador_obj {
      value = null
    }
  
    db.transaction {
      stack {
        db.query Contador {
          where = $db.Contador.user_id == $input.id_do_Usuario
          return = {type: "single"}
        } as $Contador_2
      
        conditional {
          if ($Contador_2 == null) {
            db.add Contador {
              enforce_hidden_fields = false
              data = {
                created_at: "now"
                user_id   : $input.id_do_Usuario
                Descricao : $User_1.name
                Inicial   : "ORC"
                numero    : 9999
              }
            } as $novo_contador
          
            var.update $Contador_2 {
              value = $novo_contador
            }
          }
        }
      
        var.update $contador_obj {
          value = $Contador_2
        }
      
        var $cont {
          value = $Contador_2.numero|add:1
        }
      
        var.update $newOrca {
          value = $Contador_2.Inicial|concat:$cont:""
        }
      
        db.edit Contador {
          field_name = "user_id"
          field_value = $input.id_do_Usuario
          enforce_hidden_fields = false
          data = {numero: $cont}
        } as $Contador_1
      }
    }
  }

  response = {
    Contador: $contador_obj
    newOrca : $newOrca
    User    : $User_1
  }

  guid = "vzVH3W_pf0YtieKhppn99J1ZLPI"
}