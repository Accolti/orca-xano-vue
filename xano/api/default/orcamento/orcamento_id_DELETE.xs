// Delete Orcamento record.
query "orcamento/{orcamento_id}" verb=DELETE {
  api_group = "Default"

  input {
    int orcamento_id? filters=min:1
  }

  stack {
    db.del "" {
      field_name = "id"
      field_value = $input.orcamento_id
    }
  }

  response = null
  guid = "IhMuqVhtyxjkNPzdB0nhU9ovMsU"
}