// Delete Gerados record.
query "gerados/{gerados_id}" verb=DELETE {
  api_group = "Default"

  input {
    int gerados_id? filters=min:1
  }

  stack {
    db.del Gerados {
      field_name = "id"
      field_value = $input.gerados_id
    }
  }

  response = null
  guid = "q9ATaQxOyRxiqF8iiR-2M8P1Q_Q"
}