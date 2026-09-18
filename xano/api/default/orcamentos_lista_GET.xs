query Orcamentos_Lista verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Orca {
      return = {type: "list"}
    } as $Orca_1
  }

  response = $Orca_1
  guid = "vKIimmgZuoLU6UOFsjT1DkpyrqA"
}