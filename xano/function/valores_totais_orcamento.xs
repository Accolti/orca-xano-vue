// Valores totais do orca
function Valores_totais_Orcamento {
  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    db.query Orca {
      join = {
        item: {table: "item", where: $db.Orca.id == $db.item.orca_id}
      }
    
      where = $db.Orca.id == $input.orca_id
      eval = {
        qtd      : $db.item.qtd
        cst_total: $db.item.vlr_cst_unit|mul:$db.item.qtd
        vnd_total: $db.item.vlr_vnd_unit|mul:$db.item.qtd
      }
    
      return = {
        type : "aggregate"
        group: {cod_orca: $db.Orca.cod_orca, frtB2B: $db.Orca.frtB2B}
        eval : {
          qtd      : $db.qtd|sum
          cst_total: $db.cst_total|sum
          vnd_total: $db.vnd_total|sum
        }
      }
    
      output = ["frtB2B", "qtd", "cst_total", "vnd_total"]
    } as $Orca_1
  
    !debug.stop {
      value = $Orca_1
    }
  
    var $margem {
      value = $Orca_1.vnd_total
        |first
        |divide:($Orca_1.cst_total|first)
        |subtract:1
        |multiply:100
    }
  }

  response = {result_1: $Orca_1, margem: $margem}
  tags = ["teste"]
  guid = "KXmB8FZRwQlir0D5SSOCMiNXdbA"
}