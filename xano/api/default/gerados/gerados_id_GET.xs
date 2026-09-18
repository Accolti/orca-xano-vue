// Get Gerados record
query "gerados/{gerados_id}" verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int gerados_id? filters=min:1
  }

  stack {
    db.get Gerados {
      field_name = "id"
      field_value = $input.gerados_id
    } as $gerados
  
    precondition ($gerados != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $gerados
  guid = "Ikfi21KRRzgJzKIk7bjJuzU5sAE"
}