// Delete Unidade record.
query "unidade/{unidade_id}" verb=DELETE {
  api_group = "Default"

  input {
    int unidade_id? filters=min:1
  }

  stack {
    db.del Unidade {
      field_name = "id"
      field_value = $input.unidade_id
    }
  }

  response = null
  guid = "t5fNs2u-DAeEpd025Ol6SP73dzg"
}