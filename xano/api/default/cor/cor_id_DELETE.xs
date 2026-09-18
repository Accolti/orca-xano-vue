// Delete Cor record.
query "cor/{cor_id}" verb=DELETE {
  api_group = "Default"

  input {
    int cor_id? filters=min:1
  }

  stack {
    db.del Cor {
      field_name = "id"
      field_value = $input.cor_id
    }
  }

  response = null
  guid = "xWdFJAIqRv4NPBeNE9BX5k2uyTQ"
}