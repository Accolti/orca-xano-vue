// Delete classificacao record.
query "classificacao/{classificacao_id}" verb=DELETE {
  api_group = "Default"

  input {
    int classificacao_id? filters=min:1
  }

  stack {
    db.del Classificacao {
      field_name = "id"
      field_value = $input.classificacao_id
    }
  }

  response = null
  guid = "BrdpgXmCoY2Vwz_aLiR7_-K3K0c"
}