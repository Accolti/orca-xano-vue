// Inserir Orcamento e Itens
query PedidoItem_Inserir verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    decimal margem_geral?
    decimal custo_total?
    decimal lucro_total?
    decimal total_b2b?
    decimal total_b2b_b2c?
  
    // Sem o frete B2B
    decimal total?
  }

  stack {
    !var $id_orca {
      value = 0
    }
  
    db.get Contador {
      field_name = "user_id"
      field_value = $auth.id
    } as $Contador_1
  
    !db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
    } as $Orca_0
  
    function.run Orcamento_Detalhes_v2 {
      input = {orca_id: $input.orca_id}
    } as $func_1
  
    !debug.stop {
      value = $func_1.itemS
    }
  
    db.transaction {
      stack {
        function.run pedido_func {
          input = {
            num_ped            : $func_1.ORCA_1.cod_orca|replace:$Contador_1.Inicial:""
            cod_orca           : $func_1.ORCA_1.cod_orca
            cliente_id         : $func_1.ORCA_1.cliente_id
            frtB2B             : $func_1.tot_vnd_total_b2b|subtract:$func_1.tot_vnd_total
            frtB2C             : $func_1.ORCA_1.frtB2C
            user_id            : $func_1.ORCA_1.user_id
            margem             : $input.margem_geral
            desconto           : $func_1.ORCA_1.desconto
            vlr_cst_tot        : $input.custo_total
            vlr_cst_tot_ipi    : ""
            vlr_cst_tot_imp    : ""
            vlr_vnd_total      : $input.total
            vlr_vnd_tot_ipi    : ""
            vlr_vnd_tot_imp    : ""
            vlr_vnd_tot_b2b    : $input.total_b2b
            vlr_vnd_tot_b2b_b2c: $input.total_b2b_b2c
          }
        } as $ped_1
      
        db.add ControlePedido {
          enforce_hidden_fields = false
          data = {
            created_at       : "now"
            pedido_id        : $ped_1.id
            codPedidoApp     : ""
            codPedidoVenda   : ""
            notaFiscal       : ""
            transportadoraB2B: ""
            transportadoraB2C: ""
            dataPrevisao     : null
            dataChegada      : null
            freteB2BReal     : ""
            freteB2CReal     : ""
            user_id          : $auth.id
          }
        } as $ControlePedido_1
      
        !debug.stop {
          value = $ped_1
        }
      
        db.query item {
          where = $db.item.orca_id == $input.orca_id
          return = {type: "list"}
        } as $item_1
      
        foreach ($func_1.itemS) {
          each as $item {
            db.add item_ped {
              enforce_hidden_fields = false
              data = {
                created_at       : "now"
                pedido_id        : $ped_1.id
                produto_id       : $item.produto_id
                ipi              : $item.ipi
                imp              : $item.imp
                vlr_custo        : $item.vlr_custo
                und_produto      : $item.und_produto
                larg             : $item.larg
                comp             : $item.comp
                larg_fc          : $item.larg_fc
                comp_fc          : $item.comp_fc
                borda_id         : $item.borda_id
                vlr_cst_borda    : $item.vlr_cst_borda
                und_borda        : $item.und_borda
                tipo_fator_id    : $item.tipo_fator_id
                fator_de_corte_id: $item.fator_de_corte_id
                detalhe_id       : $item.detalhe_id
                variacao_id      : $item.variacao_id
                margem           : $item.margem
                qtd              : $item.qtd
                vlr_cst_unit     : $item.vlr_cst_unit
                vlr_cst_tot      : $item.vlr_cst_unit|multiply:$item.qtd
                vlr_cst_unit_ipi : $item.vlr_cst_unit_ipi
                vlr_cst_tot_ipi  : $item.vlr_cst_unit_ipi|multiply:$item.qtd
                vlr_cst_unit_imp : $item.vlr_cst_unit_ipi
                vlr_cst_tot_imp  : $item.vlr_cst_unit_ipi|multiply:$item.qtd
                vlr_vnd_unit     : $item.vlr_vnd_unit
                vlr_vnd_tot      : $item.vlr_vnd_unit|multiply:$item.qtd
                vlr_vnd_unit_ipi : $item.vlr_vnd_unit_ipi
                vlr_vnd_tot_ipi  : $item.vlr_vnd_unit_ipi|multiply:$item.qtd
                vlr_vnd_unit_imp : $item.vlr_cst_unit_imp
                vlr_vnd_tot_imp  : $item.vlr_cst_unit_imp|multiply:$item.qtd
                vlr_vnd_unit_b2b : $item.vlr_vnd_c_taxas_unit_b2b
                vlr_vnd_tot_b2b  : $item.vlr_vnd_c_taxas_tot_b2b
                descricao        : $item.descricao
                area_user        : $item.area_user
                area_calc        : $item.area_calc
              }
            } as $item_ped_1
          }
        }
      
        function.run orca_change {
          input = {
            orca_id        : $input.orca_id
            cliente_id     : "0"
            frtB2B         : ""
            frtB2C         : ""
            validade       : null
            user_id        : "0"
            margem         : ""
            cst_tot        : ""
            luc_tot        : ""
            vnd_tot        : ""
            vnd_B2B_tot    : ""
            vnd_B2B_B2C_tot: ""
            desconto       : ""
            pedido_id      : $ped_1.id
            bAlteraMargItem: ""
          }
        } as $func_2
      }
    }
  }

  response = {pedido: $ped_1, itens: $item_ped_1}
  guid = "LWcrHEgz9K-nhVht2urwlwTGF_0"
}