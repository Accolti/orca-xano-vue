// This endpoint is responsible for sending the user off to a Google webpage to authenticate. Once complete, the user will be redirected to where this request was initiated and then depending on your requirements, the user will go down the login, signup, or continue path.
query "oauth/google/init" verb=GET {
  api_group = "google-oauth"

  input {
    text redirect_uri? filters=trim
  }

  stack {
    function.run google_oauth_getauthurl {
      input = {redirect_uri: $input.redirect_uri}
    } as $func_1
  }

  response = {authUrl: $func_1}
  guid = "776e2a77a918f0d69f8dcccb8e0546d0"
}