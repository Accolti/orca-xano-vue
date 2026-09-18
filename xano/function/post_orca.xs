function post_orca {
  input {
    dblink {
      table = "Orca"
      override = {
        cst_tot        : {hidden: true}
        luc_tot        : {hidden: true}
        vnd_tot        : {hidden: true}
        cod_orca       : {hidden: false}
        cliente_id     : {hidden: false}
        vnd_B2B_tot    : {hidden: true}
        vnd_B2B_B2C_tot: {hidden: true}
      }
    }
  }

  stack {
    var $var_CodOrc {
      value = ""
    }
  
    conditional {
      if (($input.cod_orca|is_empty) || ($input.cod_orca|is_null) || $input.cod_orca == 0) {
        !debug.stop {
          value = "PArou"
        }
      
        function.run Novo_Numero_Orcamento {
          input = {id_do_Usuario: $input.user_id}
        } as $func_1
      
        var.update $var_CodOrc {
          value = $func_1.newOrca
        }
      }
    
      else {
        !debug.stop {
          value = $input.cod_orca
        }
      
        var.update $var_CodOrc {
          value = $input.cod_orca
        }
      }
    }
  
    db.add Orca {
      enforce_hidden_fields = false
      data = {
        created_at : "now"
        cod_orca   : $var_CodOrc
        cliente_id : $input.cliente_id
        frtB2B     : $input.frtB2B
        frtB2C     : $input.frtB2C
        validade   : $input.validade
        user_id    : $input.user_id
        margem     : $input.margem
        desconto   : $input.desconto
        observacao : $input.observacao
        status     : $input.status|first_notempty:"RASCUNHO"
        eh_pedido  : $input.eh_pedido|first_notempty:false
        regime_id  : $input.regime_id
        uf_origem  : $input.uf_origem
        uf_destino : $input.uf_destino
        markup_alvo: $input.markup_alvo
      }
    } as $orca
  }

  response = $orca
  guid = "nd1MESi20B9WqOCTHcM6wd1GBLU"
}