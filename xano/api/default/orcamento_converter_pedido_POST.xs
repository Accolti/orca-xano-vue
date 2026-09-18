// novo-sis: converte um orçamento APROVADO em pedido.
// Grava eh_pedido = true, status = AGUARDANDO_FATURAMENTO e registra a transição
// na tabela de auditoria Orca_Status_Log. A partir daqui a edição fica bloqueada.
query orcamento_converter_pedido verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
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
  
    precondition (!$Orca_0.eh_pedido) {
      error_type = "badrequest"
      error = "Este orçamento já foi convertido em pedido."
    }
  
    precondition ($Orca_0.status == "APROVADO") {
      error_type = "badrequest"
      error = "Apenas orçamentos APROVADOS podem ser convertidos em pedido."
    }
  
    // O pedido já deve ter sido enviado à fábrica (Kapazi) com o nº do pedido registrado
    db.query ControlePedido {
      where = $db.ControlePedido.orca_id == $input.orca_id
      sort = {ControlePedido.id: "asc"}
      return = {type: "list"}
    } as $controleLista
  
    var $num_pedido_fabrica {
      value = ""
    }
  
    conditional {
      if (($controleLista|count) > 0) {
        var.update $num_pedido_fabrica {
          value = ($controleLista|first).num_pedido_fabrica|first_notnull:""
        }
      }
    }
  
    precondition (($num_pedido_fabrica != null) && ($num_pedido_fabrica != "")) {
      error_type = "badrequest"
      error = "Registre o Nº do Pedido da Fábrica (Kapazi) antes de converter em pedido."
    }
  
    db.transaction {
      stack {
        db.edit Orca {
          field_name = "id"
          field_value = $input.orca_id
          enforce_hidden_fields = false
          data = {status: "AGUARDANDO_FATURAMENTO", eh_pedido: true}
        } as $Orca_editada
      
        // Auditoria: registra a transição
        db.add Orca_Status_Log {
          enforce_hidden_fields = false
          data = {
            created_at     : "now"
            orca_id        : $input.orca_id
            status         : "AGUARDANDO_FATURAMENTO"
            status_anterior: $Orca_0.status
            user_id        : $auth.id
            motivo         : "Convertido em pedido"
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
  guid = "orcamento-converter-pedido-novo-sis-0001"
}