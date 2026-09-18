// Get material record
query "material/{material_id}" verb=GET {
  api_group = "Default"

  input {
    int material_id? filters=min:1
  }

  stack {
    db.get Material {
      field_name = "id"
      field_value = $input.material_id
    } as $material
  
    precondition ($material != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $material
  guid = "XsaYwnaPCapU35ZQhhA6TZ5B9CI"
}