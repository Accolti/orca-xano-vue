// This endpoint handles signup only. If the user already has signed up through Google, then this endpoint will throw an error message.
query "oauth/google/signup" verb=GET {
  api_group = "google-oauth"

  input {
    text code? filters=trim
    text redirect_uri? filters=trim
  }

  stack {
    function.run google_oauth_getaccesstoken {
      input = {code: $input.code, redirect_uri: $input.redirect_uri}
    } as $token
  
    function.run google_oauth_getuserinfo {
      input = {token: $token}
    } as $userinfo
  
    db.query User {
      where = $db.User.google_oauth.id == $userinfo.id
      return = {type: "single"}
    } as $existing_user
  
    precondition ($existing_user == null) {
      error_type = "accessdenied"
      error = "There is already an account with these credentials. Try logging in instead."
    }
  
    db.add User {
      enforce_hidden_fields = false
      data = {
        created_at  : "now"
        name        : $userinfo.name
        email       : $userinfo.email
        google_oauth: {
        id   : $userinfo.id
        name : $userinfo.name
        email: $userinfo.email
      }
      }
    } as $new_user
  
    security.create_auth_token {
      table = "User"
      extras = {}
      expiration = 86400
      id = $new_user.id
    } as $token
  }

  response = {
    token: $token
    name : $userinfo.name
    email: $userinfo.email
  }

  guid = "94edfc4e190dd4832f06e9178d04a840"
}