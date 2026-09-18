// Delete fatordecorte record.
query "fatordecorte/{fatordecorte_id}" verb=DELETE {
  api_group = "Default"

  input {
    int fatordecorte_id? filters=min:1
  }

  stack {
    db.del Fator_de_Corte {
      field_name = "id"
      field_value = $input.fatordecorte_id
    }
  }

  response = null
  guid = "OlWYw26w3ohLOgDKDv_Ro2cDfLI"
}