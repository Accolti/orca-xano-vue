// Add Teste record
query teste verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Teste"
    }
  }

  stack {
    db.add Teste {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $teste
  }

  response = $teste
  guid = "noJB6Cle6HgtIt0G37Pr_f_D1Y8"
}