// Delete Detalhe record.
query "detalhe/{detalhe_id}" verb=DELETE {
  api_group = "Default"

  input {
    int detalhe_id? filters=min:1
  }

  stack {
    db.del Detalhe {
      field_name = "id"
      field_value = $input.detalhe_id
    }
  }

  response = null
  guid = "5J6hIaTcGXx0YqK2Jt-OgTWQc6E"
}