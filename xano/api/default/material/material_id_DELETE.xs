// Delete material record.
query "material/{material_id}" verb=DELETE {
  api_group = "Default"

  input {
    int material_id? filters=min:1
  }

  stack {
    db.del Material {
      field_name = "id"
      field_value = $input.material_id
    }
  }

  response = null
  guid = "Ct3oTeIBWGHFqGMqvd25Aey2osA"
}