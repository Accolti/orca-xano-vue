// Get the record belonging to the authentication token
query "auth/me" verb=GET {
  api_group = "Teste"
  auth = "User"

  input {
  }

  stack {
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = [
        "id"
        "created_at"
        "name"
        "name_first"
        "name_last"
        "email"
        "logo"
        "google_oauth"
        "frtB2B"
        "margem"
      ]
    } as $User
  }

  response = $User
  guid = "NwwGtkTl-ljRqi_RTJmmHlaFUHI"
}