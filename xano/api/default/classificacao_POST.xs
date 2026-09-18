// Add classificacao record
query classificacao verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Classificacao"
    }
  }

  stack {
    db.add Classificacao {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $classificacao
  }

  response = $classificacao
  guid = "B2dWRoE08tGckNVwS5hme_LxsDs"
}