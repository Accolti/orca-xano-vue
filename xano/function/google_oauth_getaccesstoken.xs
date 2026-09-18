// After the user completes authentication, the user gets sent back to the "redirect_uri" along with the "code" parameter. That page is then responsible for exchanging the "code" parameter for an access token via this function.
function google_oauth_getaccesstoken {
  input {
    text code? filters=trim
    text redirect_uri? filters=trim
  }

  stack {
    api.request {
      url = "https://oauth2.googleapis.com/token"
      method = "POST"
      params = {}
        |set:"code":$input.code
        |set:"client_id":$env.workspace.google_client_id
        |set:"client_secret":$env.workspace.google_client_secret
        |set:"redirect_uri":$input.redirect_uri
        |set:"grant_type":"authorization_code"
      headers = ""
    } as $api_1
  
    precondition ($api_1.response.status == 200) {
      error_type = "accessdenied"
      error = "Access Denied."
    }
  }

  response = $api_1.response.result.access_token
  guid = "92515625e0100c3df7cfe32999b0963d"
}