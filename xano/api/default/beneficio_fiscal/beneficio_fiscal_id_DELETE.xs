// Delete Beneficio_Fiscal record.
query "beneficio_fiscal/{beneficio_fiscal_id}" verb=DELETE {
  api_group = "Default"

  input {
    int beneficio_fiscal_id? filters=min:1
  }

  stack {
    db.del Beneficio_Fiscal {
      field_name = "id"
      field_value = $input.beneficio_fiscal_id
    }
  }

  response = null
  guid = "RKJNAimblJnV_IP-5q0e-hDGhW4"
}