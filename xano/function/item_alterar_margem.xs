function Item_alterar_margem {
  input {
    int orca_id? {
      table = "Orca"
    }
  
    decimal margem?
  }

  stack {
    db.query item {
      where = $db.item.orca_id == $input.orca_id
      return = {type: "list"}
    } as $item_2
  
    !debug.stop {
      value = $item_2
    }
  
    foreach ($item_2) {
      each as $lst {
        !debug.stop {
          value = $lst.id
        }
      
        function.run item_change {
          input = {
            item_id          : $lst.id
            orca_id          : 0
            produto_id       : "0"
            ipi              : $lst.ipi
            imp              : $lst.imp
            vlr_custo        : 0
            und_produto      : ""
            larg             : 0
            comp             : 0
            larg_fc          : 0
            comp_fc          : 0
            borda_id         : "0"
            vlr_cst_borda    : $lst.vlr_cst_borda
            und_borda        : $lst.und_borda
            tipo_fator_id    : "0"
            fator_de_corte_id: "0"
            detalhe_id       : "0"
            variacao_id      : "0"
            margem           : $input.margem
            qtd              : 0
            vlr_cst_unit     : 0
            vlr_cst_unit_ipi : $lst.vlr_cst_unit_ipi
            vlr_cst_unit_imp : $lst.vlr_cst_unit_imp
            vlr_vnd_unit     : 0
            vlr_vnd_unit_ipi : $lst.vlr_vnd_unit_ipi
            vlr_vnd_unit_imp : $lst.vlr_vnd_unit_imp
            vlr_vnd_unit_b2b : 0
            descricao        : ""
            area_user        : 0
            area_calc        : 0
          }
        } as $func_1
      
        var.update $lst.margem {
          value = $input.margem
        }
      
        !debug.log {
          value = $func_1.id
        }
      }
    }
  
    function.run Orcamento_Detalhes_Function {
      input = {
        orca_codigo: ""
        newMargem  : ""
        orca_id    : $input.orca_id
      }
    } as $func_2
  
    db.add_or_edit Orca {
      field_name = "id"
      field_value = $input.orca_id
      enforce_hidden_fields = false
      data = {
        margem         : $input.margem
        cst_tot        : $func_2.tot_cst_total
        luc_tot        : $func_2.tot_lucro
        vnd_tot        : $func_2.tot_vnd_total
        vnd_B2B_tot    : $func_2.tot_vnd_total_b2b
        vnd_B2B_B2C_tot: $func_2.tot_vnd_total_b2b_b2c
      }
    } as $Orca_1
  }

  response = $item_2
  guid = "6uN9XXWbQmkySq29caWu4Z_pH-c"
}