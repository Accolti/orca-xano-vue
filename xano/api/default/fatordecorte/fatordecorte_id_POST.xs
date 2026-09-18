// Edit fatordecorte record
query "fatordecorte/{fatordecorte_id}" verb=POST {
  api_group = "Default"

  input {
    int fatordecorte_id? filters=min:1
    dblink {
      table = "Fator_de_Corte"
    }
  }

  stack {
    db.edit Fator_de_Corte {
      field_name = "id"
      field_value = $input.fatordecorte_id
      enforce_hidden_fields = false
      data = {}
    } as $fatordecorte
  }

  response = $fatordecorte
  guid = "Jw2efU5j3bOn6gkNt1JFuIGOXn0"
}