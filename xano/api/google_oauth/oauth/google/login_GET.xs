// This endpoint handles login only. If the user has not already signed up through Google, then this endpoint will throw an error message.
query "oauth/google/login" verb=GET {
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
    } as $user_1
  
    precondition ($user_1 != null) {
      error_type = "notfound"
      error = "No user exists with these credentials. Try signing up instead."
    }
  
    security.create_auth_token {
      table = "User"
      extras = {}
      expiration = 86400
      id = $user_1.id
    } as $token
  }

  response = {
    token: $token
    name : $userinfo.name
    email: $userinfo.email
  }

  guid = "766ae7320781612f60f0980e0cc7f8db"
}