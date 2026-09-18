// Query all linha records
query linha verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int material_id?
  }

  stack {
    !db.query "" {
      return = {type: "list"}
    } as $linha
  
    db.query Linha {
      join = {
        Material: {
          table: "Material"
          where: $db.Linha.material_id == $db.Material.id
        }
      }
    
      where = $db.Material.id == $input.material_id
      return = {type: "list"}
    } as $linha
  }

  response = $linha
  guid = "wKttvcPlnYPAvBvMTwK7bzkcLvw"
}