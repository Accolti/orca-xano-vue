// Query all borda records
query borda_por_material verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int material_id?
  }

  stack {
    db.query Borda {
      join = {
        Material: {
          table: "Material"
          where: $db.Material.id == $db.Borda.material_id
        }
      }
    
      where = $db.Borda.material_id == $input.material_id && $db.Borda.ativo == true
      return = {type: "list"}
    } as $borda
  }

  response = $borda
  guid = "6xebg1ijS_owM_59MGdIvHiSmSI"
}