function Orcamento_Detalhes_Function {
  input {
    text orca_codigo? filters=trim
    decimal newMargem?
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    db.query Orca {
      where = $db.Orca.id ==? $input.orca_id || $db.Orca.cod_orca ==? $input.orca_codigo
      return = {type: "single"}
      addon = [
        {
          name : "Cliente"
          input: {Cliente_id: $output.cliente_id}
          addon: [
            {
              name : "Endereco_Cliente"
              input: {cliente_id: $output.id}
              as   : "_endereco_cliente"
            }
            {
              name  : "Telefone_Cliente_of_Cliente"
              output: [
                "id"
                "created_at"
                "cliente_id"
                "tipo_telefone_id"
                "telefone"
                "descricao"
              ]
              input : {cliente_id: $output.id}
              as    : "_telefone_cliente_of_cliente"
            }
          ]
          as   : "_cliente"
        }
      ]
    } as $Orca_1
  
    !db.get Orca {
      field_name = "cod_orca"
      field_value = $input.orca_codigo
      addon = [
        {
          name : "Cliente"
          input: {Cliente_id: $output.cliente_id}
          addon: [
            {
              name : "Endereco_Cliente"
              input: {cliente_id: $output.id}
              as   : "_endereco_cliente"
            }
            {
              name : "Telefone_Cliente_of_Cliente"
              input: {cliente_id: $output.id}
              as   : "_telefone_cliente_of_cliente"
            }
          ]
          as   : "_cliente"
        }
      ]
    } as $Orca_1
  
    // OLD valor de custo unitario está somanado o IPI + IMP mais lembro que o custo unitario já tem estes valores computados
  
    !db.query item {
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
    
      where = $db.Orca.cod_orca == $Orca_1.cod_orca
      eval = {
        Descricao               : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome|concat:" "|concat:$db.Borda.nome
        vlr_cst_c_taxas_tot     : $db.item.vlr_cst_unit|!add:$db.item.vlr_cst_unit_ipi|!add:$db.item.vlr_cst_unit_imp|mul:$db.item.qtd
        vlr_cst_unit_c_taxas    : $db.item.vlr_cst_unit|!add:$db.item.vlr_cst_unit_ipi|!add:$db.item.vlr_cst_unit_imp
        vlr_vnd_unit_c_taxas    : $db.item.vlr_vnd_unit|!add:$db.item.vlr_vnd_unit_ipi|!add:$db.item.vlr_vnd_unit_imp
        vlr_vnd_c_taxas_tot     : $db.item.vlr_vnd_unit|!add:$db.item.vlr_vnd_unit_ipi|!add:$db.item.vlr_vnd_unit_imp|mul:$db.item.qtd
        vlr_vnd_c_taxas_tot_b2b : $db.item.vlr_vnd_unit
        vlr_vnd_c_taxas_unit_b2b: $db.item.vlr_vnd_unit_b2b
        lucro_total             : $db.item.vlr_vnd_unit
        freteB2B                : $db.Orca.frtB2B
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
        "area_user"
        "area_calc"
        "Descricao"
        "vlr_cst_c_taxas_tot"
        "vlr_cst_unit_c_taxas"
        "vlr_vnd_unit_c_taxas"
        "vlr_vnd_c_taxas_tot"
        "vlr_vnd_c_taxas_tot_b2b"
        "vlr_vnd_c_taxas_unit_b2b"
        "lucro_total"
        "freteB2B"
      ]
    
      addon = [
        {
          name : "Variacao"
          input: {Variacao_id: $output.variacao_id}
          as   : "_variacao"
        }
        {
          name : "Produto"
          input: {Produto_id: $output.produto_id}
          as   : "_produto"
        }
      ]
    } as $item_1
  
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
    
      where = $db.Orca.cod_orca == $Orca_1.cod_orca
      sort = {item.id: "asc"}
      eval = {
        Descricao               : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome|concat:" "|concat:$db.Borda.nome
        vlr_cst_c_taxas_tot     : $db.item.vlr_cst_unit|mul:$db.item.qtd
        vlr_vnd_unit_c_taxas    : $db.item.vlr_vnd_unit
        vlr_vnd_c_taxas_tot     : $db.item.vlr_vnd_unit|mul:$db.item.qtd
        vlr_vnd_c_taxas_tot_b2b : $db.item.vlr_vnd_unit
        vlr_vnd_c_taxas_unit_b2b: $db.item.vlr_vnd_unit_b2b
        lucro_total             : $db.item.vlr_vnd_unit
        freteB2B                : $db.Orca.frtB2B
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
        "area_user"
        "area_calc"
        "Descricao"
        "vlr_cst_c_taxas_tot"
        "vlr_cst_unit_c_taxas"
        "vlr_vnd_unit_c_taxas"
        "vlr_vnd_c_taxas_tot"
        "vlr_vnd_c_taxas_tot_b2b"
        "vlr_vnd_c_taxas_unit_b2b"
        "lucro_total"
        "freteB2B"
      ]
    
      addon = [
        {
          name : "Variacao"
          input: {Variacao_id: $output.variacao_id}
          as   : "_variacao"
        }
        {
          name : "Produto"
          input: {Produto_id: $output.produto_id}
          addon: [
            {
              name : "Classificacao"
              input: {Classificacao_id: $output.classificacao_id}
              as   : "_classificacao"
            }
          ]
          as   : "_produto"
        }
      ]
    } as $item_1
  
    !debug.stop {
      value = $item_1
    }
  
    function.run fcalcularPrazo {
      input = {itens: $item_1}
    } as $prazo_entrega
  
    !debug.stop {
      value = $prazo_entrega
    }
  
    db.get User {
      field_name = "id"
      field_value = $Orca_1.user_id
      addon = [
        {
          name : "endereco_user_of_User"
          input: {user_id: $Orca_1.user_id}
          as   : "google_oauth._endereco_user_of_user"
        }
        {
          name : "Telefone_User_of_User"
          input: {user_id: $Orca_1.user_id}
          as   : "google_oauth._telefone_user_of_user"
        }
      ]
    } as $User_1
  
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
  
    function.run fCalculaFrete {
      input = {valor_total_compra: $item_2.vlr_cst_unit_taxas}
    } as $frete_valor
  
    !debug.stop {
      value = $frete_valor
    }
  
    var $valor_medio_b2b {
      value = $frete_valor|divide:$item_2.item_qtd
    }
  
    // Valor Medio do FRETE B2B se for menos que 750
  
    !conditional {
      if ($item_2.vlr_cst_unit_taxas < 750) {
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
  
    var $marg {
      value = 0
    }
  
    !debug.stop {
      value = $item_1
    }
  
    foreach ($item_1) {
      each as $item {
        function.run Marguem_Multiplicadora {
          input = {Marguem: $item.margem}
        } as $margem_1
      
        !debug.stop {
          value = $item
        }
      
        var.update $marg {
          value = $input.newMargem|first_notempty:$item.margem
        }
      
        !debug.stop {
          value = $marg
        }
      
        conditional {
          if (($item.und_produto|to_upper) == "M2") {
            !debug.stop {
              value = "calcular"
            }
          
            function.run Valor_Venda_M2 {
              input = {
                Area_FC     : 0
                Larg_FC     : $item.larg_fc
                Comp_FC     : $item.comp_fc
                CustoM2     : $item.vlr_custo
                Margem      : $marg
                Frete_B2B   : $valor_medio_b2b|multiply:$item.qtd
                Qtd_Unidades: $item.qtd
                Custo_Borda : $item.vlr_cst_borda
                IPI         : $item.ipi
                IMP         : $item.imp
              }
            } as $func_1
          
            !conditional {
              if ($item.id == 1070) {
                debug.stop {
                  value = $func_1
                }
              }
            }
          }
        }
      
        conditional {
          if (($item.und_produto|to_upper) == "ML") {
            !debug.stop {
              value = $item
            }
          
            !debug.stop {
              value = $valor_medio_b2b
            }
          
            function.run Valor_Venda_ML {
              input = {
                Area_do_Cliente: 0
                Larg_Cliente   : $item.larg_fc
                Comp_Cliente   : $item.comp_fc
                Larg_Fixa      : $item._variacao.larg
                Tam_Total_Pca  : $item._variacao.comp
                Custo_MP_Geral : $item._variacao.valor_custo
                margem         : $marg
                Frete_B2B      : $valor_medio_b2b|multiply:$item.qtd
                Custo_Borda_ML : 0
                FC_Comprimento : 1
                IMP            : $item.imp
                IPI            : $item.ipi
                Base_Calc_MP   : $item._produto.Unidade|first
              }
            } as $func_1
          }
        }
      
        !debug.stop {
          value = $func_1
        }
      
        conditional {
          if (($item.und_produto|to_upper) == "KIT") {
            !debug.stop {
              value = $item
            }
          
            function.run Valor_Venda_Kit {
              input = {
                Area_FC            : 0
                Larg_FC            : $item.larg_fc
                Comp_FC            : $item.comp_fc
                CustoKit           : $item._variacao.valor_custo
                Margem             : $marg
                Frete_B2B          : $valor_medio_b2b|multiply:$item.qtd
                larg_kit           : $item._variacao.larg
                comp_kit           : $item._variacao.comp
                qtd_de_pecas_do_kit: $item._variacao.qtd_kit
                IPI                : $item.ipi
                IMP                : $item.imp
              }
            } as $func_1
          
            !debug.stop {
              value = $func_1
            }
          }
        }
      
        conditional {
          if (($item.und_produto|to_upper) == "UND") {
            !debug.stop {
              value = $item
            }
          
            function.run Valor_Venda_Unidade {
              input = {
                Custo_Unidade: $item._variacao.valor_custo
                Margem       : $marg
                Frete_B2B    : $valor_medio_b2b|multiply:$item.qtd
                Qtd_Unidades : $item.qtd
                IPI          : $item.ipi
                IMP          : $item.imp
                Medida       : ""
              }
            } as $func_1
          
            !debug.stop {
              value = $func_1
            }
          }
        }
      
        var.update $item.vlr_vnd_unit {
          value = $func_1.Valor_Venda_Unit
        }
      
        var.update $item.vlr_vnd_unit_c_taxas {
          value = $func_1.Valor_Venda_Unit
        }
      
        var.update $item.vlr_vnd_unit_b2b {
          value = $func_1.Valor_Venda_Unit_B2B
        }
      
        var.update $item.vlr_vnd_c_taxas_tot {
          value = $func_1.Valor_Venda_Total
        }
      
        // CRIADA ABAIXO EM 03/06/2025 - ITEM.VLR_CST_C_TAXAS_TOT = FUNC_1.VALOR_CUSTO_TOTAL
        !var $x1 {
          value = ""
        }
      
        !var.update $item.vlr_cst_c_taxas_tot {
          value = $func_1.Valor_Custo_Total
        }
      
        var.update $item.vlr_vnd_c_taxas_tot_b2b {
          value = $func_1.Valor_Venda_Total_B2B
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
      
        !var.update $tot_vnd_total_b2b {
          value = $tot_vnd_total_b2b
            |add:$item.vlr_vnd_c_taxas_tot_b2b
        }
      
        var.update $tot_vnd_total {
          value = $tot_vnd_total|add:$item.vlr_vnd_c_taxas_tot
        }
      
        var.update $tot_cst_total {
          value = $tot_cst_total|add:$item.vlr_cst_c_taxas_tot
        }
      
        !debug.stop {
          value = $item.vlr_vnd_c_taxas_tot
        }
      
        !debug.stop {
          value = $func_1
        }
      }
    }
  
    var $tot_vnd_total {
      value = $tot_vnd_total|subtract:$Orca_1.desconto
    }
  
    !debug.stop {
      value = $tot_vnd_total
    }
  
    var $tot_vnd_total_b2b {
      value = $tot_vnd_total
    }
  
    !debug.stop {
      value = $tot_vnd_total_b2b
    }
  
    function.run fCalculaFrete {
      input = {valor_total_compra: $item_2.vlr_cst_unit_taxas}
    } as $frete_valor
  
    !debug.stop {
      value = $frete_valor
    }
  
    var.update $tot_vnd_total_b2b {
      value = $tot_vnd_total_b2b|add:$frete_valor
    }
  
    !conditional {
      if ($item_2.vlr_cst_unit_taxas < 750) {
        var.update $tot_vnd_total_b2b {
          value = $tot_vnd_total_b2b|add:$Orca_1.frtB2B
        }
      }
    }
  
    var $tot_vnd_total_b2b_b2c {
      value = $tot_vnd_total_b2b|add:$Orca_1.frtB2C
    }
  
    var $margem_tot {
      value = $tot_vnd_total
        |divide:$tot_cst_total
        |subtract:1
        |multiply:100
        |round:4
    }
  
    !debug.stop {
      value = $margem_tot
    }
  
    var $desconto {
      value = $Orca_1.desconto
    }
  
    var.update $tot_lucro {
      value = $tot_vnd_total|subtract:$tot_cst_total
    }
  
    !object.entries {
      value = {}
        |set:'"Lucro Total"':$tot_lucro
        |set:'"Custo Total"':$tot_cst_total
        |set:'"Venda Total"':$tot_vnd_total
    } as $Totais
  
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
    desconto             : $desconto
    User_1               : $User_1
    prazo_entrega        : $prazo_entrega
  }

  guid = "e7-M03nVsuDx7vmsrPH2Jg7fiJY"
}