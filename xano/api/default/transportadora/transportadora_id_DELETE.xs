// Delete Transportadora record.
query "transportadora/{transportadora_id}" verb=DELETE {
  api_group = "Default"

  input {
    int transportadora_id? filters=min:1
  }

  stack {
    db.del "" {
      field_name = "id"
      field_value = $input.transportadora_id
    }
  }

  response = null
  guid = "ddZNL58LPcf2mYvu5uOOo1_g-KY"
}