// Delete Organizacao record.
query "organizacao/{organizacao_id}" verb=DELETE {
  api_group = "Default"

  input {
    int organizacao_id? filters=min:1
  }

  stack {
    db.del Organizacao {
      field_name = "id"
      field_value = $input.organizacao_id
    }
  }

  response = null
  guid = "5KrQzGDCX9ACxL5W6YxqG_aOU08"
}