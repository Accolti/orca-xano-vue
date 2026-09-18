// Edit Regra_Fiscal record
query "regra_fiscal/{regra_fiscal_id}" verb=PATCH {
  api_group = "Default"

  input {
    int regra_fiscal_id? filters=min:1
    dblink {
      table = "Regra_Fiscal"
    }
  }

  stack {
    util.get_raw_input {
      encoding = "json"
      exclude_middleware = false
    } as $raw_input
  
    db.patch Regra_Fiscal {
      field_name = "id"
      field_value = $input.regra_fiscal_id
      data = `$input|pick:($raw_input|keys)`|filter_null|filter_empty_text
    } as $regra_fiscal
  }

  response = $regra_fiscal
  guid = "ZubGqkdzjaIAseJlPgit_ZaFlHs"
}