// Query all tipo records
query tipo_por_material verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int material_id?
  }

  stack {
    db.query Tipo {
      join = {
        Material: {
          table: "Material"
          where: $db.Tipo.material_id == $db.Material.id
        }
      }
    
      where = $db.Material.id == $input.material_id
      return = {type: "list"}
    } as $tipo
  }

  response = $tipo
  guid = "WqB6ZB9eTwR-BAxAkBh6mzDr_pc"
}