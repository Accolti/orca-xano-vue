query Orcamento_Detalhes_OLD verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text orca_codigo? filters=trim
  }

  stack {
    db.get Orca {
      field_name = "cod_orca"
      field_value = $input.orca_codigo
    } as $Orca_1
  
    db.query item {
      join = {
        Orca    : {table: "Orca", where: $db.Orca.id == $db.item.orca_id}
        Produto : {
          table: "Produto"
          where: $db.item.produto_id == $db.Produto.id
        }
        Material: {
          table: "Material"
          where: $db.Material.id == $db.Produto.material_id
        }
        Linha   : {
          table: "Linha"
          type : "left"
          where: $db.Linha.id ==? $db.Produto.linha_id
        }
        Tipo    : {
          table: "Tipo"
          type : "left"
          where: $db.Tipo.id ==? $db.Produto.tipo_id
        }
        Nivel   : {
          table: "Nivel"
          type : "left"
          where: $db.Nivel.id ==? $db.Produto.nivel_id
        }
        Borda   : {
          table: "Borda"
          type : "left"
          where: $db.Borda.id ==? $db.item.borda_id
        }
      }
    
      where = $db.Orca.cod_orca == $input.orca_codigo
      eval = {
        Descricao               : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome|concat:" "|concat:$db.Borda.nome
        vlr_cst_c_taxas_tot     : $db.item.vlr_cst_unit|!add:$db.item.vlr_cst_unit_ipi|!add:$db.item.vlr_cst_unit_imp|mul:$db.item.qtd
        vlr_cst_unit_c_taxas    : $db.item.vlr_cst_unit|!add:$db.item.vlr_cst_unit_ipi|!add:$db.item.vlr_cst_unit_imp
        vlr_vnd_unit_c_taxas    : $db.item.vlr_vnd_unit|!add:$db.item.vlr_vnd_unit_ipi|!add:$db.item.vlr_vnd_unit_imp
        vlr_vnd_c_taxas_tot     : $db.item.vlr_vnd_unit|!add:$db.item.vlr_vnd_unit_ipi|!add:$db.item.vlr_vnd_unit_imp|mul:$db.item.qtd
        vlr_vnd_c_taxas_tot_b2b : $db.item.vlr_vnd_unit
        vlr_vnd_c_taxas_unit_b2b: $db.item.vlr_vnd_unit_b2b
        lucro_total             : $db.item.vlr_vnd_unit
      }
    
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "orca_id"
        "produto_id"
        "ipi"
        "imp"
        "vlr_custo"
        "und_produto"
        "larg"
        "comp"
        "larg_fc"
        "comp_fc"
        "borda_id"
        "vlr_cst_borda"
        "und_borda"
        "tipo_fator_id"
        "fator_de_corte_id"
        "variacao_id"
        "margem"
        "qtd"
        "vlr_cst_unit"
        "vlr_cst_unit_ipi"
        "vlr_cst_unit_imp"
        "vlr_vnd_unit"
        "vlr_vnd_unit_ipi"
        "vlr_vnd_unit_imp"
        "vlr_vnd_unit_b2b"
        "Descricao"
        "vlr_cst_c_taxas_tot"
        "vlr_cst_unit_c_taxas"
        "vlr_vnd_unit_c_taxas"
        "vlr_vnd_c_taxas_tot"
        "vlr_vnd_c_taxas_tot_b2b"
        "vlr_vnd_c_taxas_unit_b2b"
        "lucro_total"
      ]
    
      addon = [
        {
          name : "Variacao"
          input: {Variacao_id: $output.variacao_id}
          as   : "_variacao"
        }
      ]
    } as $item_1
  
    // Retorna a QTD total de Itens e o valor Total de Custo
    db.query item {
      where = $db.item.orca_id == $Orca_1.id
      eval = {vlr_cst_unit_taxas: $db.item.vlr_cst_unit|mul:$db.item.qtd}
      return = {
        type: "aggregate"
        eval: {
          item_qtd          : $db.item.qtd|sum
          vlr_cst_unit_taxas: $db.vlr_cst_unit_taxas|sum
        }
      }
    } as $item_2
  
    // Retorna a QTD total de Itens e o valor Total de Custo
    !db.query item {
      where = $db.item.orca_id == $Orca_1.id
      eval = {vlr_cst_unit_taxas: $db.item.vlr_cst_unit|mul:$db.item.qtd}
      return = {
        type: "aggregate"
        eval: {
          item_qtd          : $db.item.qtd|sum
          vlr_cst_unit_taxas: $db.vlr_cst_unit_taxas|sum
        }
      }
    } as $item_2
  
    !debug.stop {
      value = $item_1
    }
  
    // Valor Medio do FRETE B2B se for menos que 1500
    conditional {
      if ($item_2.vlr_cst_unit_taxas < 1500) {
        var $valor_medio_b2b {
          value = $Orca_1.frtB2B|divide:$item_2.item_qtd
        }
      }
    
      else {
        var $valor_medio_b2b {
          value = 0
        }
      }
    }
  
    !debug.stop {
      value = $valor_medio_b2b
    }
  
    var $tot_lucro {
      value = 0
    }
  
    var $tot_cst_total {
      value = 0
    }
  
    var $tot_vnd_total_b2b {
      value = 0
    }
  
    var $tot_vnd_total {
      value = 0
    }
  
    foreach ($item_1) {
      each as $item {
        var.update $item.vlr_vnd_unit_b2b {
          value = $item.vlr_vnd_unit|add:$valor_medio_b2b
        }
      
        var.update $item.vlr_vnd_c_taxas_tot_b2b {
          value = $item.vlr_vnd_c_taxas_tot
            |add:($item.qtd|multiply:$valor_medio_b2b)
        }
      
        !var.update $item.vlr_vnd_c_taxas_tot_b2b {
          value = $item.vlr_vnd_c_taxas_tot|add:$Orca_1.frtB2B
        }
      
        conditional {
          if (($item.und_produto|to_upper) == "KIT") {
            var.update $item.Descricao {
              value = $item.Descricao
                |concat:$item._variacao.tipo:" "
                |concat:$item._variacao.qtd_kit:" c/ "
                |concat:" unds":""
                |concat:$item._variacao.modelo:" - "
            }
          }
        
          else {
            !var.update $item.Descricao {
              value = $item.Descricao
                |concat:$item._variacao.tipo:" "
                |concat:$item._variacao.qtd_kit:" c/ "
                |concat:" unds":""
                |concat:$item._variacao.modelo:" - "
            }
          }
        }
      
        var.update $item.vlr_vnd_c_taxas_unit_b2b {
          value = $item.vlr_vnd_c_taxas_tot_b2b|divide:$item.qtd
        }
      
        !var.update $item.vlr_vnd_c_taxas_unit_b2b {
          value = $item.vlr_vnd_c_taxas_tot_b2b|add:$valor_medio_b2b
        }
      
        var.update $item.lucro_total {
          value = $item.vlr_vnd_c_taxas_tot
            |subtract:$item.vlr_cst_c_taxas_tot
        }
      
        var.update $tot_lucro {
          value = $tot_lucro|add:$item.lucro_total
        }
      
        var.update $tot_vnd_total_b2b {
          value = $tot_vnd_total_b2b
            |add:$item.vlr_vnd_c_taxas_tot_b2b
        }
      
        var.update $tot_vnd_total {
          value = $tot_vnd_total|add:$item.vlr_vnd_c_taxas_tot
        }
      
        var.update $tot_cst_total {
          value = $tot_cst_total|add:$item.vlr_cst_c_taxas_tot
        }
      
        var $teste {
          value = $item_1._variacao.modelo|first
        }
      }
    }
  
    var $margem_tot {
      value = $tot_vnd_total
        |divide:$tot_cst_total
        |subtract:1
        |multiply:100
    }
  
    var $tot_vnd_total_b2b_b2c {
      value = $tot_vnd_total_b2b|add:$Orca_1.frtB2C
    }
  
    !debug.stop {
      value = $valor_medio_b2b
    }
  }

  response = {
    ORCA_1               : $Orca_1
    itemS                : $item_1
    tot_lucro            : $tot_lucro
    tot_cst_total        : $tot_cst_total
    tot_vnd_total        : $tot_vnd_total
    tot_vnd_total_b2b    : $tot_vnd_total_b2b
    margem_tot           : $margem_tot
    tot_vnd_total_b2b_b2c: $tot_vnd_total_b2b_b2c
    frete_B2C            : $Orca_1.frtB2C
    valor_medio_b2b      : $valor_medio_b2b
    teste                : $teste
    item_2               : $item_2
  }

  guid = "xEi7b1j7AGu1dAVntdSBhvHz6iM"
}