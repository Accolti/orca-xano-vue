// Query all material records
query material_plus verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Material {
      sort = {material.id: "asc"}
      eval = {uuu: $db.material.nome|concat:$db.material.ncm}
      return = {type: "list"}
    } as $material
  
    foreach ($material) {
      each as $mat {
        var.update $mat.nome {
          value = $mat.id|concat:$mat.nome:"-"
        }
      }
    }
  }

  response = {result_1: $material}
  guid = "_YBSQNIQ6MWogXclKXSfNhGCea8"
}