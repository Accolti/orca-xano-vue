// Edit Regime record
query "regime/{regime_id}" verb=POST {
  api_group = "Default"

  input {
    int regime_id? filters=min:1
    dblink {
      table = "Regime"
    }
  }

  stack {
    db.edit Regime {
      field_name = "id"
      field_value = $input.regime_id
      enforce_hidden_fields = false
      data = {}
    } as $regime
  }

  response = $regime
  guid = "zem7DOn6aX9SHDigrd3ISiS94Dk"
}