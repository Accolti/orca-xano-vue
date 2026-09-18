// Get fatordecorte record
query "fatordecorte/{fatordecorte_id}" verb=GET {
  api_group = "Default"

  input {
    int fatordecorte_id? filters=min:1
  }

  stack {
    db.get Fator_de_Corte {
      field_name = "id"
      field_value = $input.fatordecorte_id
    } as $fatordecorte
  
    precondition ($fatordecorte != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $fatordecorte
  guid = "8YmifWqdAC1RcMUR47wPqWqAnqk"
}