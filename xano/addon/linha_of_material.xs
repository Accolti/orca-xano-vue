addon Linha_of_Material {
  input {
    int material_id? {
      table = "Material"
    }
  }

  stack {
    db.query Linha {
      where = $db.Linha.material_id == $input.material_id
      return = {type: "list"}
    }
  }

  guid = "sQUs3fg0bIG4Wqb5UR1djYT05lA"
}