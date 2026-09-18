// Edit material record
query "material/{material_id}" verb=POST {
  api_group = "Default"

  input {
    int material_id? filters=min:1
    dblink {
      table = "Material"
    }
  }

  stack {
    db.edit Material {
      field_name = "id"
      field_value = $input.material_id
      enforce_hidden_fields = false
      data = {}
    } as $material
  }

  response = $material
  guid = "q5nuyO2nh9IE_fiBv7Kq55Hywmg"
}