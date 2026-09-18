// novo-sis: atualiza o status do orçamento (RASCUNHO → AGUARDANDO_RETORNO → APROVADO →
// AGUARDANDO_FATURAMENTO → FATURADO → ENTREGUE, com RECUSADO/CANCELADO como alternativas).
// Grava data_envio/data_aprovacao quando aplicável, motivo_recusa quando RECUSADO/CANCELADO
// e registra a transição na tabela de auditoria Orca_Status_Log.
query orcamento_status verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    text status? filters=trim|upper
  
    // Motivo/observação opcional (RECUSADO/CANCELADO e reversões)
    text motivo? filters=trim
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
    } as $Orca_0
  
    precondition ($Orca_0 != null) {
      error_type = "notfound"
      error = "Orçamento não encontrado."
    }
  
    precondition ($Orca_0.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "Acesso negado: apenas o dono pode alterar o status."
    }
  
    var $ehFilhoSt {
      value = false
    }
  
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role"]
    } as $stCaller
  
    conditional {
      if (($stCaller.role == "vendedor") || ($stCaller.role == "vendedor_master")) {
        var.update $ehFilhoSt {
          value = true
        }
      }
    }
  
    var $descPendente {
      value = false
    }
  
    conditional {
      if (($ehFilhoSt) && (($Orca_0.desconto|first_notnull:0) > 0) && (($Orca_0.desconto_status == "pendente") || ($Orca_0.desconto_status == "recusado") || (($Orca_0.desconto_status|is_null) && ($Orca_0.desconto_aprovado == false)))) {
        var.update $descPendente {
          value = true
        }
      }
    }
  
    precondition (($descPendente != true) || ($input.status == "RASCUNHO") || ($input.status == "CANCELADO") || ($input.status == "RECUSADO")) {
      error_type = "badrequest"
      error = "Desconto acima do limite aguarda aprovação do pai."
    }
  
    // Pedido convertido (eh_pedido=true) não pode voltar para status de orçamento,
    // mas o fluxo do pedido segue permitido: FATURADO → ENTREGUE e CANCELADO.
    precondition (!$Orca_0.eh_pedido || $input.status == "FATURADO" || $input.status == "ENTREGUE" || $input.status == "CANCELADO") {
      error_type = "badrequest"
      error = "Este orçamento foi convertido em pedido. Só é possível Faturar (FATURADO), Entregar (ENTREGUE) ou Cancelar (CANCELADO)."
    }
  
    var $data_envio {
      value = $Orca_0.data_envio
    }
  
    var $data_aprovacao {
      value = $Orca_0.data_aprovacao
    }
  
    var $motivo_recusa {
      value = $Orca_0.motivo_recusa
    }
  
    conditional {
      if ($input.status == "AGUARDANDO_RETORNO" || $input.status == "ENVIADO") {
        var.update $data_envio {
          value = "now"
        }
      }
    }
  
    conditional {
      if ($input.status == "APROVADO") {
        var.update $data_aprovacao {
          value = "now"
        }
      }
    }
  
    conditional {
      if ($input.status == "RECUSADO" || $input.status == "CANCELADO") {
        var.update $motivo_recusa {
          value = $input.motivo
            |first_notnull:$Orca_0.motivo_recusa
        }
      }
    }
  
    db.transaction {
      stack {
        db.edit Orca {
          field_name = "id"
          field_value = $input.orca_id
          enforce_hidden_fields = false
          data = {
            status        : $input.status
            data_envio    : $data_envio
            data_aprovacao: $data_aprovacao
            motivo_recusa : $motivo_recusa
          }
        } as $Orca_editada
      
        // Auditoria: registra a transição
        db.add Orca_Status_Log {
          enforce_hidden_fields = false
          data = {
            created_at     : "now"
            orca_id        : $input.orca_id
            status         : $input.status
            status_anterior: $Orca_0.status
            user_id        : $auth.id
            motivo         : $input.motivo
          }
        } as $Log_1
      }
    }
  
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
      addon = [
        {
          name : "Cliente"
          input: {Cliente_id: $output.cliente_id}
          as   : "_cliente"
        }
      ]
    } as $Orca_1
  }

  response = {ORCA_1: $Orca_1}
  tags = ["orcamento", "novo-sis"]
  guid = "orcamento-status-novo-sis-0001"
}