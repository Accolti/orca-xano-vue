// Cria/edita uma faixa de comissão da empresa. Admin gerencia as próprias;
// admin_geral pode gerenciar de qualquer empresa (user_id).
query faixa_comissao_salvar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int id? {
      table = "Faixa_Comissao"
    }
  
    int user_id? {
      table = "User"
    }
  
    decimal faixa_min?
    decimal faixa_max?
    decimal comissao_total_perc?
    int ordem?
    bool ativo?=true
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
  
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role"]
    } as $me
  
    precondition ($me.role == "admin" || $me.role == "admin_geral") {
      error_type = "accessdenied"
      error = "Apenas administradores configuram faixas de comissão."
    }
  
    // Serviço de comissões (plano). admin_geral (sistema) sempre passa.
    function.run f_tem_comissoes {
      input = {user_id: $auth.id}
    } as $temComissoes
  
    precondition (($me.role == "admin_geral") || ($temComissoes)) {
      error_type = "accessdenied"
      error = "Sem acesso a esta funcionalidade."
    }
  
    precondition (($input.comissao_total_perc != null) && ($input.comissao_total_perc > 0)) {
      error_type = "badrequest"
      error = "Informe a comissão total (%)."
    }
  
    var $dono_id {
      value = $auth.id
    }
  
    conditional {
      if (($me.role == "admin_geral") && ($input.user_id != null)) {
        var.update $dono_id {
          value = $input.user_id
        }
      }
    }
  
    conditional {
      if ($input.id != null) {
        db.get Faixa_Comissao {
          field_name = "id"
          field_value = $input.id
        } as $existente
      
        precondition ($existente != null) {
          error_type = "notfound"
          error = "Faixa não encontrada."
        }
      
        precondition (($me.role == "admin_geral") || ($existente.user_id == $auth.id)) {
          error_type = "accessdenied"
          error = "Você não pode editar esta faixa."
        }
      
        db.edit Faixa_Comissao {
          field_name = "id"
          field_value = $input.id
          enforce_hidden_fields = false
          data = {
            user_id            : $dono_id
            faixa_min          : $input.faixa_min|first_notnull:0
            faixa_max          : $input.faixa_max
            comissao_total_perc: $input.comissao_total_perc
            ordem              : $input.ordem
            ativo              : $input.ativo
          }
        } as $salva
      }
    
      else {
        db.add Faixa_Comissao {
          enforce_hidden_fields = false
          data = {
            created_at         : "now"
            user_id            : $dono_id
            faixa_min          : $input.faixa_min|first_notnull:0
            faixa_max          : $input.faixa_max
            comissao_total_perc: $input.comissao_total_perc
            ordem              : $input.ordem
            ativo              : $input.ativo
          }
        } as $salva
      }
    }
  }

  response = $salva
  tags = ["comissao", "f3"]
  guid = "faixa-comissao-salvar-f3-0001"
}