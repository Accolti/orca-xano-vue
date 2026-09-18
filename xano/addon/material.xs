addon Material {
  input {
    int Material_id? {
      table = "Material"
    }
  }

  stack {
    db.query Material {
      where = $db.Material.id == $input.Material_id
      return = {type: "single"}
    }
  }

  guid = "y__xZ-0854ErFbJIH5Pt3RfdNuw"
}