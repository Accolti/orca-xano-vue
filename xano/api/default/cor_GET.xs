// Query all Cor records
query cor verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Cor {
      return = {type: "list"}
    } as $cor
  }

  response = $cor
  guid = "LDm1vy-Xbk_PJF-Oxo0zHpwdH38"
}