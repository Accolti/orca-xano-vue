// Query all fatordecorte records
query fatordecorte verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Fator_de_Corte {
      return = {type: "list"}
    } as $fatordecorte
  }

  response = $fatordecorte
  guid = "DZ5UjpsTRR7j6pwec7IPY164d9o"
}