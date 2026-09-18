// Delete Regra_Fiscal record.
query "regra_fiscal/{regra_fiscal_id}" verb=DELETE {
  api_group = "Default"

  input {
    int regra_fiscal_id? filters=min:1
  }

  stack {
    db.del Regra_Fiscal {
      field_name = "id"
      field_value = $input.regra_fiscal_id
    }
  }

  response = null
  guid = "ucI_kn0eSNpaq2LK9WYKPcC-UpI"
}