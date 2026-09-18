// Get Orcamento record
query "orcamento/{orcamento_id}" verb=GET {
  api_group = "Default"

  input {
    int orcamento_id? filters=min:1
  }

  stack {
    db.get "" {
      field_name = "id"
      field_value = $input.orcamento_id
    } as $orcamento
  
    precondition ($orcamento != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $orcamento
  guid = "A53bJgPMfoAqMB3fySuOJHctxlc"
}