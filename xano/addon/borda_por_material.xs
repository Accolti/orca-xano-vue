addon Borda_Por_Material {
  input {
    int material_id? {
      table = "Material"
    }
  
    text nomeBorda? filters=trim
  }

  stack {
    db.query Borda {
      where = $db.Borda.material_id == $input.material_id && ($db.Borda.nome|to_upper) ==? ($input.nomeBorda|to_upper)
      return = {type: "single"}
    }
  }

  guid = "beqou0l4n-TUMhsogpRpG3myxck"
}