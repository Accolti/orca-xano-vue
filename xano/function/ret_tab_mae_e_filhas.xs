function Ret_TabMaeEFilhas {
  input {
    int id_material?
    int id_organizacao?
    text? nmMaterial? filters=trim
  }

  stack {
    db.query Material {
      join = {
        Linha      : {
          table: "Linha"
          type : "left"
          where: $db.Material.id == $db.Linha.material_id
        }
        Tipo       : {
          table: "Tipo"
          type : "left"
          where: $db.Tipo.material_id ==? $db.Material.id
        }
        Nivel      : {
          table: "Nivel"
          type : "left"
          where: $db.Material.id == $db.Nivel.material_id
        }
        Borda      : {
          table: "Borda"
          type : "left"
          where: $db.Material.id ==? $db.Borda.material_id
        }
        Organizacao: {
          table: "Organizacao"
          where: $db.Material.organizacao_id == $db.Organizacao.id
        }
      }
    
      where = ($db.Material.nome|to_upper) ==? ($input.nmMaterial|to_upper) || $db.Material.id ==? $input.id_material && ($db.Organizacao.id == $input.id_organizacao)
      eval = {
        Linha: $db.Linha.nome
        Tipo : $db.Tipo.nome
        Nivel: $db.Nivel.nome
        Borda: $db.Borda.nome
      }
    
      return = {
        type : "aggregate"
        group: {Material: $db.Material.nome}
        eval : {
          Linha: $db.Linha|count_distinct
          Tipo : $db.Tipo|count_distinct
          Nivel: $db.Nivel|count_distinct
          Borda: $db.Borda|count_distinct
        }
      }
    } as $Material_1
  
    !db.query Material {
      join = {
        Linha      : {
          table: "Linha"
          type : "left"
          where: $db.Material.id == $db.Linha.material_id
        }
        Tipo       : {
          table: "Tipo"
          type : "left"
          where: $db.Tipo.material_id ==? $db.Material.id
        }
        Nivel      : {
          table: "Nivel"
          type : "left"
          where: $db.Material.id == $db.Nivel.material_id
        }
        Borda      : {
          table: "Borda"
          type : "left"
          where: $db.Material.id ==? $db.Borda.material_id
        }
        Organizacao: {
          table: "Organizacao"
          where: $db.Material.organizacao_id == $db.Organizacao.id
        }
      }
    
      where = ($db.Material.nome|to_upper) ==? ($input.nmMaterial|to_upper) || $db.Material.id ==? $input.id_material && ($db.Organizacao.id == $input.id_organizacao)
      eval = {
        Linha  : $db.Linha.nome
        Tipo   : $db.Tipo.nome
        Nivel  : $db.Nivel.nome
        Borda  : $db.Borda.nome
        nm_tipo: $db.Tipo.nome
      }
    
      return = {
        type : "aggregate"
        group: {Material: $db.Material.nome, nm_tipo: $db.nm_tipo}
        eval : {
          Linha: $db.Linha|count_distinct
          Tipo : $db.Tipo|count_distinct
          Nivel: $db.Nivel|count_distinct
          Borda: $db.Borda|count_distinct
        }
      }
    } as $Material_1
  }

  response = {Material_1: $Material_1}
  guid = "XgAGzHJfEhqaoVwS4-G8lDJ9Bfg"
}