// This creates the URL from your environment variables that you will use to send the user to for authentication.
function google_oauth_getauthurl {
  input {
    text redirect_uri? filters=trim
  }

  stack {
    precondition ($env.workspace.google_client_id != "") {
      error = 'Please set your "google_client_id" environment variable.'
    }
  
    precondition ($env.workspace.google_client_secret != "") {
      error = 'Please set your "google_client_secret" environment variable.'
    }
  
    var $google_url {
      value = "https://accounts.google.com/o/oauth2/auth"
        |url_addarg:"response_type":"code"
        |url_addarg:"access_type":"online"
        |url_addarg:"client_id":$env.workspace.google_client_id
        |url_addarg:"redirect_uri":$input.redirect_uri
        |url_addarg:"state":""
        |url_addarg:"scope":"https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"
        |url_addarg:"prompt":"select_account"
    }
  }

  response = $google_url
  guid = "276ca71d0ecb26851107a4383daff23b"
}