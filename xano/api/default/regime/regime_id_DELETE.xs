// Delete Regime record.
query "regime/{regime_id}" verb=DELETE {
  api_group = "Default"

  input {
    int regime_id? filters=min:1
  }

  stack {
    db.del Regime {
      field_name = "id"
      field_value = $input.regime_id
    }
  }

  response = null
  guid = "UwutcM2X6MuL6EXq038TKrh0KN8"
}