// This gets user information stored within Google which is retrieved via access token.
function google_oauth_getuserinfo {
  input {
    text token? filters=trim
  }

  stack {
    api.request {
      url = "https://www.googleapis.com/userinfo/v2/me"
      method = "GET"
      params = {}|set:"access_token":$input.token
      headers = ""
    } as $api_1
  
    precondition ($api_1.response.status == 200) {
      error = "Access Denied"
    }
  }

  response = $api_1.response.result
  guid = "e48e00e2693eb739fa26a9ff1ae89b7e"
}