addon item_of_Orca {
  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    db.query item {
      join = {
        Produto : {
          table: "Produto"
          where: $db.item.produto_id == $db.Produto.id
        }
        Material: {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Linha   : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo    : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel   : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Nivel.id
        }
        Borda   : {
          table: "Borda"
          type : "left"
          where: $db.item.borda_id ==? $db.Borda.id
        }
      }
    
      where = $db.item.orca_id ==? $input.orca_id
      eval = {
        material         : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome|concat:" "|concat:$db.Borda.nome
        vlr_vnd_total_b2b: $db.item.vlr_vnd_unit_b2b|mul:$db.item.qtd
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
        "material"
        "vlr_vnd_total_b2b"
      ]
    }
  }

  guid = "ZAfedridK0FhIdsPB7UDLY7f8Ho"
}