// Edit classificacao record
query "classificacao/{classificacao_id}" verb=POST {
  api_group = "Default"

  input {
    int classificacao_id? filters=min:1
    dblink {
      table = "Classificacao"
    }
  }

  stack {
    db.edit Classificacao {
      field_name = "id"
      field_value = $input.classificacao_id
      enforce_hidden_fields = false
      data = {}
    } as $classificacao
  }

  response = $classificacao
  guid = "_nMmYH_2Wn4I1c2i_y4Z9LFo0t8"
}