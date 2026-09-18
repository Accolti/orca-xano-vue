// Get Orca record
query "orca/{orca_id}" verb=GET {
  api_group = "Default"

  input {
    int orca_id? filters=min:1
  }

  stack {
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
    } as $orca
  
    precondition ($orca != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $orca
  guid = "N3Q68ORAu9Yywu_KsyvzpvtWN_w"
}