// Edit TestWithDate record
query "testwithdate/{testwithdate_id}" verb=PATCH {
  api_group = "Default"

  input {
    int testwithdate_id? filters=min:1
    dblink {
      table = "TestWithDate"
    }
  }

  stack {
    db.get TestWithDate {
      field_name = "id"
      field_value = $input.testwithdate_id
    } as $testwithdate
  
    db.edit TestWithDate {
      field_name = "id"
      field_value = $input.testwithdate_id
      enforce_hidden_fields = false
      data = {initial: $input.initial}
    } as $testwithdate
  
    !var $object {
      value = {}
        |set:"a":$input.initial
        |set:"b":2
        |set:"c":3
    }
  }

  response = {result_1: $testwithdate}
  guid = "yoXGcpJZR9if0vQA9EyKElGjr9o"
}