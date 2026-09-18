addon Tipo_of_Material {
  input {
    int material_id? {
      table = "Material"
    }
  }

  stack {
    db.query Tipo {
      where = $db.Tipo.material_id == $input.material_id
      return = {type: "list"}
    }
  }

  guid = "wohAGdL1DQG5iSOCVvB1cYaTmK0"
}