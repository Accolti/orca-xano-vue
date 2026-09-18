// Delete Tipo_Variacao record.
query "tipo_variacao/{tipo_variacao_id}" verb=DELETE {
  api_group = "Default"

  input {
    int tipo_variacao_id? filters=min:1
  }

  stack {
    db.del Tipo_Variacao {
      field_name = "id"
      field_value = $input.tipo_variacao_id
    }
  }

  response = null
  guid = "NXy_pl_7PGnLQX9KAah2OuOGvlM"
}