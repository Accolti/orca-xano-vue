// Get Aliquotas_icms record
query "aliquotas_icms/{aliquotas_icms_id}" verb=GET {
  api_group = "Default"

  input {
    int aliquotas_icms_id? filters=min:1
  }

  stack {
    db.get Aliquotas_icms {
      field_name = "id"
      field_value = $input.aliquotas_icms_id
    } as $aliquotas_icms
  
    precondition ($aliquotas_icms != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $aliquotas_icms
  guid = "iKWAxr3CcW1mHr_kS4EkOCpIKQQ"
}