addon Produto_of_Detalhe {
  input {
    int detalhe_id? {
      table = "Detalhe"
    }
  
    text nmMaterial? filters=trim
    text nmLinha? filters=trim
    text nmTipo? filters=trim
    text nmNivel? filters=trim
  }

  stack {
    db.query Produto {
      join = {
        Material: {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Linha   : {
          table: "Linha"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo    : {table: "Tipo", where: $db.Produto.tipo_id ==? $db.Tipo.id}
        Nivel   : {
          table: "Nivel"
          where: $db.Produto.nivel_id ==? $db.Nivel.id
        }
      }
    
      where = $db.Produto.detalhe_id == $input.detalhe_id && ($db.Material.nome|to_upper) == ($input.nmMaterial|to_upper) && ($db.Linha.nome|to_upper) ==? ($input.nmLinha|to_upper) && ($db.Tipo.nome|to_upper) ==? ($input.nmTipo|to_upper) && ($db.Nivel.nome|to_upper) ==? ($input.nmNivel|to_upper)
      return = {type: "list"}
    }
  }

  guid = "ptizNezrb1TLmxN2tm5R2varP38"
}