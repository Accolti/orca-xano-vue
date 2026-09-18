// Get tipo record
query "tipo/{tipo_id}" verb=GET {
  api_group = "Default"

  input {
    int tipo_id? filters=min:1
  }

  stack {
    db.get Tipo {
      field_name = "id"
      field_value = $input.tipo_id
    } as $tipo
  
    precondition ($tipo != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $tipo
  guid = "ueD8DmfpxXoMDyUQ9lBXme6Z1U0"
}