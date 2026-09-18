// Query all Regra_Fiscal records
query regra_fiscal verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Regra_Fiscal {
      return = {type: "list"}
    } as $regra_fiscal
  }

  response = $regra_fiscal
  guid = "4V3M0gTrTpJuwLiCcWbZPH-iyN4"
}