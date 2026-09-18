// Delete Tipo_Telefone record.
query "tipo_telefone/{tipo_telefone_id}" verb=DELETE {
  api_group = "Default"

  input {
    int tipo_telefone_id? filters=min:1
  }

  stack {
    db.del Tipo_Telefone {
      field_name = "id"
      field_value = $input.tipo_telefone_id
    }
  }

  response = null
  guid = "4I0dNOR809LDBViyzAotEL27drA"
}