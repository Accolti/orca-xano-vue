// Query all Tipo_Variacao records
query tipo_variacao verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Tipo_Variacao {
      return = {type: "list"}
    } as $tipo_variacao
  }

  response = $tipo_variacao
  guid = "4EKNcR4bfmJE6k4LVOciXPtuBGo"
}