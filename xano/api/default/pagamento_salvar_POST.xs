// novo-sis: substitui as parcelas financeiras (boletos/Pix/cartão) de um orçamento (Orca).
query pagamento_salvar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    object[] parcelas? {
      schema {
        decimal valor?
        date? vencimento?
        int forma_pagamento_id?
      }
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
  
    precondition ($Orca_0.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "Acesso negado."
    }
  
    db.transaction {
      stack {
        db.query Boleto {
          where = $db.Boleto.orca_id == $input.orca_id
          return = {type: "list"}
        } as $parcelas_antigas
      
        foreach ($parcelas_antigas) {
          each as $item {
            db.del Boleto {
              field_name = "id"
              field_value = $item.id
            }
          }
        }
      
        foreach ($input.parcelas) {
          each as $item {
            db.add Boleto {
              enforce_hidden_fields = false
              data = {
                created_at        : "now"
                orca_id           : $input.orca_id
                vencimento        : $item.vencimento
                valor             : $item.valor
                forma_pagamento_id: $item.forma_pagamento_id
                user_id           : $auth.id
              }
            } as $Parcela
          }
        }
      }
    }
  }

  response = {ok: true, quantidade: $input.parcelas|count}
  guid = "pagamento-salvar-novo-sis-0001"
}