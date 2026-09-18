addon Borda_of_Material_Lst {
  input {
    int material_id? {
      table = "Material"
    }
  }

  stack {
    db.query Borda {
      where = $db.Borda.material_id == $input.material_id
      return = {type: "list"}
    }
  }

  guid = "6U6y0QT7yCrwm2EJlvCnJzpOR4g"
}