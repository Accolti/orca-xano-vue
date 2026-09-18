query Material_Dependentes verb=GET {
  api_group = "Admim"

  input {
    text nome_material? filters=trim|upper
  }

  stack {
    db.query Material {
      join = {
        Linha: {
          table: "Linha"
          type : "left"
          where: $db.Material.id ==? $db.Linha.material_id
        }
        Tipo : {
          table: "Tipo"
          type : "left"
          where: $db.Material.id ==? $db.Tipo.material_id
        }
        Nivel: {
          table: "Nivel"
          type : "left"
          where: $db.Material.id ==? $db.Nivel.material_id
        }
        Borda: {
          table: "Borda"
          type : "left"
          where: $db.Material.id ==? $db.Borda.material_id
        }
      }
    
      where = ($db.Material.nome|to_upper) ==? ($input.nome_material|to_upper)
      sort = {Material.id: "asc"}
      return = {type: "list"}
      addon = [
        {
          name : "Linha_of_Material"
          input: {material_id: $output.id}
          as   : "_linha_of_material"
        }
        {
          name  : "Tipo_of_Material"
          output: ["id", "nome", "material_id"]
          input : {material_id: $output.id}
          as    : "_tipo_of_material"
        }
        {
          name  : "Nivel_of_Material"
          output: ["id", "material_id", "nome"]
          input : {material_id: $output.id}
          as    : "_nivel_of_material"
        }
        {
          name  : "Borda_of_Material_Lst"
          output: ["id", "nome", "material_id", "valor"]
          input : {material_id: $output.id}
          as    : "_borda_por_material"
        }
      ]
    } as $Mat
  }

  response = $Mat
  guid = "ukOqCS0Oh0JPAIRJatW31AYiYNs"
}