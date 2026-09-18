// Get Tipo_Telefone record
query "tipo_telefone/{tipo_telefone_id}" verb=GET {
  api_group = "Default"

  input {
    int tipo_telefone_id? filters=min:1
  }

  stack {
    db.get Tipo_Telefone {
      field_name = "id"
      field_value = $input.tipo_telefone_id
    } as $tipo_telefone
  
    precondition ($tipo_telefone != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $tipo_telefone
  guid = "-0FpDyJ7FXGXZQfapAsg2_n8pck"
}