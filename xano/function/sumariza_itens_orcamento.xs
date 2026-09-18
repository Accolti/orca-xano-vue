function SumarizaItensOrcamento {
  input {
    int orca_id? {
      table = "Orca"
    }
  
    // Item em edição: excluído da soma para não contar 2x na base do frete B2B
    int exclude_item_id? {
      table = "item"
    }
  }

  stack {
    db.query item {
      where = $db.item.orca_id == $input.orca_id && ($input.exclude_item_id == null || $db.item.id != $input.exclude_item_id)
      eval = {
        vlr_cst_nota_tot: $db.item.vlr_cst_nota_unit|mul:$db.item.qtd
      }
    
      return = {
        type : "aggregate"
        group: {item_orca_id1: $db.item.orca_id}
        eval : {cst_nota_orca: $db.vlr_cst_nota_tot|sum}
      }
    
      output = ["cst_nota_orca"]
    } as $item1
  }

  response = $item1
  guid = "0iI0t2Q2_LENL1yRerfwyjkAckA"
}