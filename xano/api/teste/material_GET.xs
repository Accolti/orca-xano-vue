query material verb=GET {
  api_group = "Teste"

  input {
  }

  stack {
    db.query Material {
      where = $db.Material.Classificacao == "Personalizado"
      return = {type: "list"}
    } as $Material_1
  }

  response = {result_1: $model, "[]": []}
  guid = "QSsUOITCfy2HpQXsWkbj0pS0W9o"
}