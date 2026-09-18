// Query all Beneficio_Fiscal records
query beneficio_fiscal verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Beneficio_Fiscal {
      return = {type: "list"}
    } as $beneficio_fiscal
  }

  response = $beneficio_fiscal
  guid = "t_1WwZkaWjfaqER7IJiuq7VhcTk"
}