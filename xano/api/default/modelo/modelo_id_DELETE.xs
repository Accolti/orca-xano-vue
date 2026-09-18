// Delete Modelo record.
query "modelo/{modelo_id}" verb=DELETE {
  api_group = "Default"

  input {
    int modelo_id? filters=min:1
  }

  stack {
    db.del Modelo {
      field_name = "id"
      field_value = $input.modelo_id
    }
  }

  response = null
  guid = "K7wEqn7ZQrZ_cQ3IF-btj3ZWoAg"
}