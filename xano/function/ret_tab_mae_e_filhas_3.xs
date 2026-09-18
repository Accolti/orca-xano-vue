function Ret_TabMaeEFilhas_3 {
  input {
    int id_material?
    int id_organizacao?
    text? nmMaterial? filters=trim
  }

  stack {
    db.query Borda {
      return = {type: "list"}
    } as $Borda1
  
    debug.stop {
      value = $Borda1
    }
  
    db.query Produto {
      return = {type: "list"}
    } as $Produto1
  
    debug.stop {
      value = $Produto1
    }
  
    db.query Material {
      join = {
        Linha      : {
          table: "Linha"
          type : "left"
          where: $db.Material.id ==? $db.Linha.material_id
        }
        Nivel      : {
          table: "Nivel"
          type : "left"
          where: $db.Material.id ==? $db.Nivel.material_id
        }
        Borda      : {
          table: "Borda"
          type : "left"
          where: $db.Material.id ==? $db.Borda.material_id
        }
        Organizacao: {
          table: "Organizacao"
          where: $db.Material.organizacao_id ==? $db.Organizacao.id
        }
        Produto    : {
          table: "Produto"
          where: $db.Material.id ==? $db.Produto.material_id
        }
        Tipo       : {
          table: "Tipo"
          type : "left"
          where: $db.Tipo.material_id ==? $db.Material.id
        }
        Detalhe    : {
          table: "Detalhe"
          type : "left"
          where: $db.Produto.detalhe_id ==? $db.Detalhe.id
        }
        Variacao   : {
          table: "Variacao"
          type : "left"
          where: $db.Detalhe.id ==? $db.Variacao.detalhe_id
        }
      }
    
      where = ($db.Material.nome|to_upper) ==? ($input.nmMaterial|to_upper) || $db.Material.id ==? $input.id_material && ($db.Organizacao.id == $input.id_organizacao)
      eval = {
        Linha   : $db.Linha.nome
        Tipo    : $db.Tipo.nome
        Nivel   : $db.Nivel.nome
        Borda   : $db.Borda.nome
        Variacao: $db.Variacao.id
        Produto : $db.Produto.id
      }
    
      return = {
        type : "aggregate"
        group: {
          Material   : $db.Material.nome
          Material_id: $db.Material.id
          Produto_id : $db.Produto
        }
        eval : {
          Linha   : $db.Linha|count_distinct
          Tipo    : $db.Tipo|count_distinct
          Nivel   : $db.Nivel|count_distinct
          Borda   : $db.Borda|count_distinct
          Variacao: $db.Variacao|count_distinct
        }
      }
    
      output = [
        "Material"
        "Material_id"
        "Produto_id"
        "Linha"
        "Tipo"
        "Nivel"
        "Borda"
        "Variacao"
      ]
    } as $Material_1
  }

  response = {Material_1: $Material_1}
  guid = "VYZlIu9fVRqWyqzdSOGA3Xye5s8"
}