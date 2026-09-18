// Add tipofator record
query tipofator verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Tipo_Fator"
    }
  }

  stack {
    db.add Tipo_Fator {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $tipofator
  }

  response = $tipofator
  guid = "5ho77pQIepR9ekDttCoXJ2lZDm0"
}