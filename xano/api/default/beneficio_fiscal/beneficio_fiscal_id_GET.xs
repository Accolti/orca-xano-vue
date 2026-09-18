// Get Beneficio_Fiscal record
query "beneficio_fiscal/{beneficio_fiscal_id}" verb=GET {
  api_group = "Default"

  input {
    int beneficio_fiscal_id? filters=min:1
  }

  stack {
    db.get Beneficio_Fiscal {
      field_name = "id"
      field_value = $input.beneficio_fiscal_id
    } as $beneficio_fiscal
  
    precondition ($beneficio_fiscal != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $beneficio_fiscal
  guid = "zIoBKLZTzeuTv_No0CbY0Zf5HTY"
}