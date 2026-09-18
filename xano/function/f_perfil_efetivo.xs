// Resolve o perfil EFETIVO de um usuário: sobe a cadeia (vendedor_pai_id) até o
// admin/admin_geral (dono da empresa) e devolve a config do topo (fornecedor, UF,
// regime, empresa p/ documentos, margem, frete, validade). Filhos não guardam cópia.
function f_perfil_efetivo {
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
  
    db.get User {
      field_name = "id"
      field_value = $top_id
      output = [
        "id"
        "name"
        "razao"
        "fantasia"
        "cnpj"
        "ie"
        "cpf"
        "isPJ"
        "uf"
        "regime_id"
        "organizacao_id"
        "margem"
        "frtB2B"
        "DiasVencimentoOrcamento"
        "logo"
        "role"
        "desconto_livre_perc"
        "desconto_max_perc"
        "plano"
      ]
    } as $topo
  }

  response = $topo
  tags = ["perfil", "hierarquia"]
  guid = "perfil-efetivo-f3-0001"
}