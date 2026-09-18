// Get TestWithDate record
query "testwithdate/{testwithdate_id}" verb=GET {
  api_group = "Default"

  input {
    int testwithdate_id? filters=min:1
  }

  stack {
    db.get TestWithDate {
      field_name = "id"
      field_value = $input.testwithdate_id
    } as $testwithdate
  
    precondition ($testwithdate != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $testwithdate
  guid = "PJ2AGQrSs3m5tXHcRpzb9XCm8ws"
}