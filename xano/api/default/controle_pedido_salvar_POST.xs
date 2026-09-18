// novo-sis: salva (cria ou atualiza) os dados de controle Kapazi/faturamento de um pedido.
// Upsert por orca_id (add_or_edit). Só atualiza campos enviados — campos null não sobrescrevem.
query controle_pedido_salvar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    date? data_envio_fabrica
    text num_pedido_fabrica? filters=trim
    date? data_aprovacao_layout
    text num_pedido_venda? filters=trim
    text num_nf? filters=trim
    text forma_pagamento_fabrica? filters=trim
    decimal desconto_kapazi_perc?
    text desconto_kapazi_motivo? filters=trim
    text cod_rastreio? filters=trim
    text transportadoraB2B? filters=trim
    text transportadoraB2C? filters=trim
    date? dataPrevisao
    date? dataChegada
    decimal freteB2BReal?
    decimal freteB2CReal?
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
  
    precondition ($input.orca_id != null) {
      error_type = "badrequest"
      error = "orca_id é obrigatório."
    }
  
    // Captura o valor atual do desconto Kapazi ANTES do upsert (para o log de mudanças)
    db.query ControlePedido {
      where = $db.ControlePedido.orca_id == $input.orca_id
      return = {type: "single"}
      output = ["id", "desconto_kapazi_perc"]
    } as $controle_atual
  
    var $oldPerc {
      value = null
    }
  
    conditional {
      if ($controle_atual != null) {
        var.update $oldPerc {
          value = $controle_atual.desconto_kapazi_perc
        }
      }
    }
  
    db.add_or_edit ControlePedido {
      field_name = "orca_id"
      field_value = $input.orca_id
      enforce_hidden_fields = false
      data = {
        orca_id                : $input.orca_id
        data_envio_fabrica     : $input.data_envio_fabrica
        num_pedido_fabrica     : $input.num_pedido_fabrica
        data_aprovacao_layout  : $input.data_aprovacao_layout
        num_pedido_venda       : $input.num_pedido_venda
        num_nf                 : $input.num_nf
        forma_pagamento_fabrica: $input.forma_pagamento_fabrica
        desconto_kapazi_perc   : $input.desconto_kapazi_perc
        cod_rastreio           : $input.cod_rastreio
        transportadoraB2B      : $input.transportadoraB2B
        transportadoraB2C      : $input.transportadoraB2C
        dataPrevisao           : $input.dataPrevisao
        dataChegada            : $input.dataChegada
        freteB2BReal           : $input.freteB2BReal
        freteB2CReal           : $input.freteB2CReal
        user_id                : $auth.id
      }
    } as $controle
  
    // Grava no log apenas quando o % mudou (inclui a 1ª definição: anterior nulo)
    conditional {
      if ($input.desconto_kapazi_perc != null && ($oldPerc == null || $input.desconto_kapazi_perc != $oldPerc)) {
        db.query item {
          where = $db.item.orca_id == $input.orca_id
          return = {type: "list"}
          output = ["qtd", "vlr_cst_nota_unit"]
        } as $itens_orca
      
        api.lambda {
          code = """
            const itens = $var.itens_orca || [];
            const total = itens.reduce((s, i) => s + ((Number(i.vlr_cst_nota_unit) || 0) * (Number(i.qtd) || 0)), 0);
            return { total: Number(total.toFixed(2)) };
            """
          timeout = 10
        } as $base_custo
      
        db.get Orca {
          field_name = "id"
          field_value = $input.orca_id
        } as $Orca_0
      
        var $frete_efetivo_rs {
          value = 0
        }
      
        conditional {
          if ($input.freteB2BReal != null && $input.freteB2BReal > 0) {
            var.update $frete_efetivo_rs {
              value = $input.freteB2BReal
            }
          }
        
          else {
            conditional {
              if ($Orca_0 != null) {
                var.update $frete_efetivo_rs {
                  value = $Orca_0.frtB2B|first_notnull:0
                }
              }
            }
          }
        }
      
        var $valor_log {
          value = $base_custo.total
        }
      
        var.update $valor_log {
          value = ($valor_log * $input.desconto_kapazi_perc) / 100
        }
      
        db.add Desconto_Kapazi_Log {
          enforce_hidden_fields = false
          data = {
            orca_id          : $input.orca_id
            desconto_anterior: $oldPerc
            desconto_novo    : $input.desconto_kapazi_perc
            valor_desconto_rs: $valor_log
            frete_efetivo_rs : $frete_efetivo_rs
            user_id          : $auth.id
            motivo           : $input.desconto_kapazi_motivo
            created_at       : "now"
          }
        } as $log_desconto
      }
    }
  }

  response = $controle
  tags = ["orcamento", "novo-sis", "pedido"]
  guid = "controle-pedido-salvar-novo-sis-0001"
}