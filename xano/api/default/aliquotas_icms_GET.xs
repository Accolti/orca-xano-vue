// Query all Aliquotas_icms records
query aliquotas_icms verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Aliquotas_icms {
      return = {type: "list"}
    } as $aliquotas_icms
  }

  response = $aliquotas_icms
  guid = "i6d1rCMHqF1ytENeKWbiYeL6umw"
}