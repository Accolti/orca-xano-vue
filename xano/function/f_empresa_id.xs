// Resolve o ID da EMPRESA (dono da conta) de um usuário: sobe a cadeia
// vendedor_pai_id até o topo (admin). Para admin/admin_geral devolve o próprio id.
// Usado para resolver as taxas de cartão por empresa.
function f_empresa_id {
  input {
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $input.user_id
      output = ["id", "role", "vendedor_pai_id"]
    } as $atual
  
    var $top_id {
      value = $input.user_id
    }
  
    conditional {
      if (($atual.role == "vendedor") || ($atual.role == "vendedor_master")) {
        db.get User {
          field_name = "id"
          field_value = $atual.vendedor_pai_id
          output = ["id", "role", "vendedor_pai_id"]
        } as $pai
      
        conditional {
          if ($pai.role == "vendedor_master" && ($pai.vendedor_pai_id != null) && ($pai.vendedor_pai_id > 0)) {
            var.update $top_id {
              value = $pai.vendedor_pai_id
            }
          }
        
          else {
            var.update $top_id {
              value = $pai.id
            }
          }
        }
      }
    }
  }

  response = $top_id
  tags = ["perfil", "hierarquia", "taxas"]
  guid = "f-empresa-id-0001"
}
