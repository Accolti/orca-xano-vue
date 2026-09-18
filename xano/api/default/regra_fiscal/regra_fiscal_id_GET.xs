// Get Regra_Fiscal record
query "regra_fiscal/{regra_fiscal_id}" verb=GET {
  api_group = "Default"

  input {
    int regra_fiscal_id? filters=min:1
  }

  stack {
    db.get Regra_Fiscal {
      field_name = "id"
      field_value = $input.regra_fiscal_id
    } as $regra_fiscal
  
    precondition ($regra_fiscal != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $regra_fiscal
  guid = "_GgwZ8ieQRHn-bGUqjxgPnNWxnA"
}