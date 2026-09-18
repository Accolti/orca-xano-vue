// Cria/edita uma taxa de cartão da empresa. Admin da empresa; admin_geral escolhe
// a conta (user_id). Sempre grava origem "manual" e atualiza `atualizado_em`.
query taxa_banco_salvar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int id? {
      table = "Taxa_Banco"
    }
  
    int user_id? {
      table = "User"
    }
  
    int provedor_id? {
      table = "Provedor"
    }
  
    int parcelas?
    decimal cc_taxa?
    text canal? filters=trim
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
      output = ["id", "role", "vendedor_pai_id"]
    } as $me
  
    // Admin: role explícita OU legado sem role e sem pai (dono da conta)
    precondition ($me.role == "admin" || $me.role == "admin_geral" || (($me.role == null || $me.role == "") && ($me.vendedor_pai_id == null || $me.vendedor_pai_id == 0))) {
      error_type = "accessdenied"
      error = "Apenas administradores gerenciam as taxas."
    }
  
    precondition (($input.parcelas != null) && ($input.parcelas > 0)) {
      error_type = "badrequest"
      error = "Informe o número de parcelas."
    }
  
    precondition ($input.cc_taxa != null) {
      error_type = "badrequest"
      error = "Informe a taxa do cartão."
    }
  
    precondition (($input.canal == null) || ($input.canal == "cartao_link") || ($input.canal == "cartao_celular") || ($input.canal == "cartao_pos")) {
      error_type = "badrequest"
      error = "Canal inválido."
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
  
    function.run f_empresa_id {
      input = {user_id: $dono_id}
    } as $empresa_id
  
    conditional {
      if ($input.id != null) {
        db.get Taxa_Banco {
          field_name = "id"
          field_value = $input.id
        } as $existente
      
        precondition ($existente != null) {
          error_type = "notfound"
          error = "Taxa não encontrada."
        }
      
        precondition (($me.role == "admin_geral") || ($existente.user_id == $empresa_id)) {
          error_type = "accessdenied"
          error = "Você não pode editar esta taxa."
        }
      
        db.edit Taxa_Banco {
          field_name = "id"
          field_value = $input.id
          enforce_hidden_fields = false
          data = {
            user_id      : $empresa_id
            provedor_id  : $input.provedor_id
            parcelas     : $input.parcelas
            cc_taxa      : $input.cc_taxa
            canal        : $input.canal
            ativo        : $input.ativo
            origem       : "manual"
            atualizado_em: "now"
          }
        } as $salva
      }
    
      else {
        db.add Taxa_Banco {
          enforce_hidden_fields = false
          data = {
            user_id      : $empresa_id
            provedor_id  : $input.provedor_id
            parcelas     : $input.parcelas
            cc_taxa      : $input.cc_taxa
            canal        : $input.canal
            ativo        : $input.ativo
            origem       : "manual"
            atualizado_em: "now"
            created_at   : "now"
          }
        } as $salva
      }
    }
  }

  response = $salva
  tags = ["novo-sis", "taxas"]
  guid = "taxa-banco-salvar-0001"
}
