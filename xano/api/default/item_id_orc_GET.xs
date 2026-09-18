// Query all item records
query item_Id_Orc verb=GET {
  api_group = "Default"

  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    db.query item {
      join = {
        Orca         : {table: "Orca", where: $db.item.orca_id == $db.Orca.id}
        Produto      : {
          table: "Produto"
          where: $db.item.produto_id == $db.Produto.id
        }
        Material     : {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Linha        : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo         : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel        : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Nivel.id
        }
        Borda        : {
          table: "Borda"
          type : "left"
          where: $db.item.borda_id ==? $db.Borda.id
        }
        Variacao     : {
          table: "Variacao"
          type : "left"
          where: $db.item.variacao_id ==? $db.Variacao.id
        }
        Tipo_Variacao: {
          table: "Tipo_Variacao"
          type : "left"
          where: $db.Tipo_Variacao.id ==? $db.Variacao.tipo_variacao_id
        }
        Cor          : {
          table: "Cor"
          type : "left"
          where: $db.Cor.id ==? $db.Variacao.cor_id
        }
        Modelo       : {
          table: "Modelo"
          type : "left"
          where: $db.Modelo.id ==? $db.Variacao.modelo_id
        }
      }
    
      where = $db.item.orca_id ==? $input.orca_id
      eval = {
        peso           : $db.Material.peso
        vlr_vnd_tot_b2b: $db.item.vlr_vnd_unit_b2b|mul:$db.item.qtd
        vlr_cst_tot_b2b: $db.item.vlr_cst_unit|mul:$db.item.qtd|add:$db.Orca.frtB2B
        lucro_total    : $db.item.vlr_vnd_unit|sub:$db.item.vlr_cst_unit|mul:$db.item.qtd
        material       : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome
        borda          : $db.Borda.nome
        larg_var       : $db.Variacao.larg
        comp_var       : $db.Variacao.comp
        modelo_var     : $db.Modelo.Descricao
        qtd_kit_var    : $db.Variacao.qtd_kit
        cor_var        : $db.Cor.Descricao
        desc_var       : $db.Tipo_Variacao.Descricao
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
        "detalhe_id"
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
        "descricao"
        "peso"
        "vlr_vnd_tot_b2b"
        "vlr_cst_tot_b2b"
        "lucro_total"
        "material"
        "borda"
        "larg_var"
        "comp_var"
        "modelo_var"
        "qtd_kit_var"
        "cor_var"
        "desc_var"
      ]
    } as $item
  
    var $vlr_vnd_total_pedido {
      value = 0
    }
  
    var $vlr_cst_total_pedido {
      value = 0
    }
  
    var $vlr_luc_total_pedido {
      value = 0
    }
  
    foreach ($item) {
      each as $xpto {
        var.update $xpto.desc_variacao {
          value = "Teste"
        }
      
        !var $desc_var {
          value = "%d teste %d legal %s até o fim %s."
            |sprintf:123:456:"quase lá":"acabou"
        }
      
        var.update $vlr_cst_total_pedido {
          value = $vlr_cst_total_pedido|add:$xpto.vlr_cst_tot_b2b
        }
      
        var.update $vlr_vnd_total_pedido {
          value = $vlr_vnd_total_pedido|add:$xpto.vlr_vnd_tot_b2b
        }
      }
    }
  
    var.update $vlr_luc_total_pedido {
      value = $vlr_vnd_total_pedido|subtract:$vlr_cst_total_pedido
    }
  }

  response = {
    result_1            : $item
    vlr_cst_total_pedido: $vlr_cst_total_pedido
    vlr_vnd_total_pedido: $vlr_vnd_total_pedido
    vlr_luc_total_pedido: $vlr_luc_total_pedido
  }

  guid = "YNBzb7oU_IC8CTE8iQ2VIoYMQMM"
}