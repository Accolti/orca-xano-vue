addon Nivel_of_Material {
  input {
    int material_id? {
      table = "Material"
    }
  }

  stack {
    db.query Nivel {
      where = $db.Nivel.material_id == $input.material_id
      return = {type: "list"}
    }
  }

  guid = "ne0nzPesEySAC0hh-3AjmAwMnPw"
}