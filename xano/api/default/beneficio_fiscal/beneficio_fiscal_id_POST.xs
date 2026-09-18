// Edit Beneficio_Fiscal record
query "beneficio_fiscal/{beneficio_fiscal_id}" verb=POST {
  api_group = "Default"

  input {
    int beneficio_fiscal_id? filters=min:1
    dblink {
      table = "Beneficio_Fiscal"
    }
  }

  stack {
    db.edit Beneficio_Fiscal {
      field_name = "id"
      field_value = $input.beneficio_fiscal_id
      enforce_hidden_fields = false
      data = {}
    } as $beneficio_fiscal
  }

  response = $beneficio_fiscal
  guid = "3VVNIEVuM_AFxRE1YQ0ozQq9H3Y"
}