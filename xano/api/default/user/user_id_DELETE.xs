// Delete user record.
query "user/{user_id}" verb=DELETE {
  api_group = "Default"

  input {
    int user_id? filters=min:1
  }

  stack {
    db.del User {
      field_name = "id"
      field_value = $input.user_id
    }
  }

  response = null
  guid = "jyB7moHFddXbIFeS3ZBquxN-8Eo"
}