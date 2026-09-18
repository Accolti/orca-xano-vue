// Delete nivel record.
query "nivel/{nivel_id}" verb=DELETE {
  api_group = "Default"

  input {
    int nivel_id? filters=min:1
  }

  stack {
    db.del Nivel {
      field_name = "id"
      field_value = $input.nivel_id
    }
  }

  response = null
  guid = "a_m1oMoi4KyhcrzwUvMtvPYYPiw"
}