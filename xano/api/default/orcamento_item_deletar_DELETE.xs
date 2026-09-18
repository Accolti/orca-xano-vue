// Remove um item do orçamento e recalcula os totais (frete Kapazi sobre o novo somatório).
query orcamento_item_deletar verb=DELETE {
  api_group = "Default"
  auth = "User"

  input {
    int item_id? {
      table = "item"
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
  
    db.get item {
      field_name = "id"
      field_value = $input.item_id
    } as $item_existente
  
    precondition ($item_existente != null) {
      error_type = "notfound"
      error = "Item não encontrado."
    }
  
    db.get Orca {
      field_name = "id"
      field_value = $item_existente.orca_id
    } as $Orca_0
  
    precondition (($Orca_0 != null) && ($Orca_0.user_id == $auth.id)) {
      error_type = "accessdenied"
      error = "Acesso negado: apenas o dono pode alterar o orçamento."
    }
  
    var $pedidoBloqueado {
      value = false
    }
  
    conditional {
      if ($Orca_0 != null) {
        var.update $pedidoBloqueado {
          value = ($Orca_0.eh_pedido == true)
        }
      }
    }
  
    precondition ($pedidoBloqueado != true) {
      error_type = "badrequest"
      error = "Orçamento convertido em pedido. Edição bloqueada."
    }
  
    db.transaction {
      stack {
        db.del item {
          field_name = "id"
          field_value = $input.item_id
        }
      
        // Itens mudaram → limpa as condições de pagamento (ficam desatualizadas)
        db.edit Orca {
          field_name = "id"
          field_value = $item_existente.orca_id
          enforce_hidden_fields = false
          data = {condicoes_pagamento: ""}
        } as $Orca_cond_limpa
      
        // Recálculo dinâmico por somatório após a remoção
      
        function.run Orcamento_Recalcular_Totais {
          input = {orca_id: $item_existente.orca_id}
        } as $func_1
      
        db.get Orca {
          field_name = "id"
          field_value = $item_existente.orca_id
        } as $Orca_1
      }
    }
  }

  response = {
    totais: $func_1.totais
    ORCA_1: $Orca_1
    itemS : $func_1.itemS
  }

  guid = "kbqCyDUgcEPMdCqwWZwtOA"
}