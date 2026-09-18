// Query all tipofator records
query tipofator verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Tipo_Fator {
      return = {type: "list"}
    } as $tipofator
  }

  response = $tipofator
  guid = "ngsbGWEEDSeMqJLtlHqUldUJARc"
}