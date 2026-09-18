// Get tipofator record
query "tipofator/{tipofator_id}" verb=GET {
  api_group = "Default"

  input {
    int tipofator_id? filters=min:1
  }

  stack {
    db.get Tipo_Fator {
      field_name = "id"
      field_value = $input.tipofator_id
    } as $tipofator
  
    precondition ($tipofator != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $tipofator
  guid = "MV1rQ7MmjKm1TGODc7OHKZRLFRM"
}