// Delete Boleto record.
query "boleto/{boleto_id}" verb=DELETE {
  api_group = "Default"

  input {
    int boleto_id? filters=min:1
  }

  stack {
    db.del Boleto {
      field_name = "id"
      field_value = $input.boleto_id
    }
  }

  response = null
  guid = "TueYV72FQbuxHh99UG82Fsp1EbQ"
}