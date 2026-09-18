// Get Ramo record
query "ramo/{ramo_id}" verb=GET {
  api_group = "Default"

  input {
    int ramo_id? filters=min:1
  }

  stack {
    db.get Ramo {
      field_name = "id"
      field_value = $input.ramo_id
    } as $ramo
  
    precondition ($ramo != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $ramo
  guid = "BIk3peJdX4Ix1JF4m_xGFP6D1kk"
}