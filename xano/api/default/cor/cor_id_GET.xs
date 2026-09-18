// Get Cor record
query "cor/{cor_id}" verb=GET {
  api_group = "Default"

  input {
    int cor_id? filters=min:1
  }

  stack {
    db.get Cor {
      field_name = "id"
      field_value = $input.cor_id
    } as $cor
  
    precondition ($cor != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $cor
  guid = "blHx3HXZJQbwSnfn7wSco8E1tBs"
}