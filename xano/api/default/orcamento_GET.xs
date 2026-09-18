// Query all Orcamento records
query orcamento verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query "" {
      return = {type: "list"}
    } as $orcamento
  }

  response = $orcamento
  guid = "BFWqf39nLBh-uVWuOFRq6yywgxA"
}