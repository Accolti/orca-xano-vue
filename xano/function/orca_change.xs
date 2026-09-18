function orca_change {
  input {
    int orca_id? filters=min:1
    dblink {
      table = "Orca"
      override = {
        frtB2B  : {hidden: true}
        frtB2C  : {hidden: true}
        cod_orca: {hidden: true}
        desconto: {hidden: true}
      }
    }
  
    // Flag se for true vai alterar a margem da  tabela item tb... (de todos os itens pois o valor da margem na orça é a margem media de todos os itens.)
    bool bAlteraMargItem?
  
    int? freteB2C?
  
    // Desconto
    decimal? desc?
  
    decimal? freteB2B?
  }

  stack {
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
    } as $orca
  
    var $pedidoBloqueado {
      value = false
    }
  
    conditional {
      if ($orca != null) {
        var.update $pedidoBloqueado {
          value = ($orca.eh_pedido == true)
        }
      }
    }
  
    precondition ($pedidoBloqueado != true) {
      error_type = "badrequest"
      error = "Orçamento convertido em pedido. Edição bloqueada."
    }
  
    function.run Valores_totais_Orcamento {
      input = {orca_id: $input.orca_id}
    } as $tot_orc
  
    var $Margem {
      value = $input.margem|first_notempty:$orca.margem
    }
  
    function.run Marguem_Multiplicadora {
      input = {Marguem: $Margem}
    } as $margem_multiplicadora
  
    var $CUSTO_Total {
      value = $input.cst_tot
        |first_notempty:($tot_orc.result_1.cst_total|first)
    }
  
    !debug.stop {
      value = $CUSTO_Total
    }
  
    var $VENDA_Total {
      value = $input.vnd_tot
        |first_notempty:($CUSTO_Total|multiply:$margem_multiplicadora)
    }
  
    !debug.stop {
      value = $VENDA_Total
    }
  
    var.update $VENDA_Total {
      value = $VENDA_Total
        |subtract:($input.desc|first_notnull:$orca.desconto)
    }
  
    !debug.stop {
      value = $VENDA_Total
    }
  
    var $Desconto {
      value = $input.desc|first_notnull:$orca.desconto
    }
  
    var $FreteB2B {
      value = $input.freteB2B|first_notnull:$orca.frtB2B
    }
  
    var $FreteB2C {
      value = $input.freteB2C|first_notnull:$orca.frtB2C
    }
  
    var $LUCRO_Total {
      value = $VENDA_Total
        |subtract:($tot_orc.result_1.cst_total|first)
    }
  
    var $VENDA_B2B_Total {
      value = $VENDA_Total
    }
  
    !debug.stop {
      value = $CUSTO_Total
    }
  
    conditional {
      if ($CUSTO_Total <= 750) {
        var.update $VENDA_B2B_Total {
          value = $VENDA_B2B_Total|add:$FreteB2B
        }
      }
    }
  
    var $VENDA_B2B_B2C_Total {
      value = $VENDA_B2B_Total|add:$FreteB2C
    }
  
    !debug.stop {
      value = $VENDA_B2B_B2C_Total
    }
  
    db.edit Orca {
      field_name = "id"
      field_value = $input.orca_id
      enforce_hidden_fields = false
      data = {
        cliente_id     : $input.cliente_id|first_notempty:$orca.cliente_id
        frtB2B         : $FreteB2B
        frtB2C         : $FreteB2C
        validade       : $input.validade|first_notempty:$orca.validade
        user_id        : $input.user_id|first_notempty:$orca.user_id
        margem         : $Margem
        cst_tot        : $CUSTO_Total
        luc_tot        : $LUCRO_Total
        vnd_tot        : $VENDA_Total
        vnd_B2B_tot    : $VENDA_B2B_Total
        vnd_B2B_B2C_tot: $VENDA_B2B_B2C_Total
        desconto       : $Desconto
      }
    } as $orca
  
    conditional {
      if ($input.bAlteraMargItem) {
        function.run Item_alterar_margem {
          input = {orca_id: $input.orca_id, margem: $Margem}
        } as $func_1
      }
    }
  }

  response = $orca
  guid = "w-AU0kbKuv2MTFw1ni-K_A9SORo"
}