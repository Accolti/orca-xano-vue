// Query all Detalhe records
query detalhe verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Detalhe {
      return = {type: "list"}
    } as $detalhe
  }

  response = $detalhe
  guid = "3EGFhJ_BwLJbpUxOc506KKPDfV0"
}