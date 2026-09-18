// Query all Tipo_Telefone records
query tipo_telefone verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Tipo_Telefone {
      return = {type: "list"}
    } as $tipo_telefone
  }

  response = $tipo_telefone
  guid = "63x81WEO6hbLpOk2rSMiP7j0A-8"
}