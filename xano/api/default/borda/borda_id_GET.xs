// Get borda record
query "borda/{borda_id}" verb=GET {
  api_group = "Default"

  input {
    int borda_id? filters=min:1
  }

  stack {
    db.get Borda {
      field_name = "id"
      field_value = $input.borda_id
    } as $borda
  
    precondition ($borda != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $borda
  guid = "9K4O4UV-M2_ElH3Z1tdMbhCQ8Qc"
}