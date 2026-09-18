// Faixas de comissão visíveis ao usuário (resolução automática da empresa dona).
// admin_geral pode filtrar por user_id (empresa).
query faixas_comissao verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role", "vendedor_pai_id", "percentual_comissao"]
    } as $me
  
    // Serviço de comissões (plano). admin_geral (sistema) sempre passa.
    function.run f_tem_comissoes {
      input = {user_id: $auth.id}
    } as $temComissoes
  
    precondition (($me.role == "admin_geral") || ($temComissoes)) {
      error_type = "accessdenied"
      error = "Sem acesso a esta funcionalidade."
    }
  
    var $target_id {
      value = $auth.id
    }
  
    conditional {
      if ($me.role == "vendedor" && ($me.vendedor_pai_id != null) && ($me.vendedor_pai_id > 0)) {
        db.get User {
          field_name = "id"
          field_value = $me.vendedor_pai_id
          output = ["id", "role", "vendedor_pai_id"]
        } as $pai
      
        conditional {
          if ($pai.role == "vendedor_master" && ($pai.vendedor_pai_id != null) && ($pai.vendedor_pai_id > 0)) {
            var.update $target_id {
              value = $pai.vendedor_pai_id
            }
          }
        
          else {
            var.update $target_id {
              value = $pai.id
            }
          }
        }
      }
    
      else {
        conditional {
          if ($me.role == "vendedor_master" && ($me.vendedor_pai_id != null) && ($me.vendedor_pai_id > 0)) {
            var.update $target_id {
              value = $me.vendedor_pai_id
            }
          }
        
          else {
            conditional {
              if (($me.role == "admin_geral") && ($input.user_id != null)) {
                var.update $target_id {
                  value = $input.user_id
                }
              }
            }
          }
        }
      }
    }
  
    db.query Faixa_Comissao {
      where = $db.Faixa_Comissao.user_id == $target_id
      sort = {faixa_min: "asc"}
      return = {type: "list"}
      output = [
        "id"
        "user_id"
        "faixa_min"
        "faixa_max"
        "comissao_total_perc"
        "ordem"
        "ativo"
      ]
    } as $faixas
  }

  response = {
    faixas             : $faixas
    papel              : $me.role
    percentual_comissao: $me.percentual_comissao
    empresa_id         : $target_id
  }

  tags = ["comissao", "f3"]
  guid = "faixas-comissao-f3-0001"
}