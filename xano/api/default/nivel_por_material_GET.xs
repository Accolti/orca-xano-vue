// Query all nivel records
query nivel_por_material verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int material_id filters=
  }

  stack {
    db.query Nivel {
      join = {
        Material: {
          table: "Material"
          where: $db.Nivel.material_id == $db.Material.id
        }
      }
    
      where = $db.Nivel.material_id == $input.material_id
      return = {type: "list"}
    } as $nivel
  }

  response = $nivel
  guid = "PHQUegQmsrefTjInnK5d_pKrFrQ"
}