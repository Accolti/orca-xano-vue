// Query all linha records
query linha_todas verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    function.run f_linha_todas as $func_1
  }

  response = $func_1
  guid = "nOvrN3TKttHab2XjtDvV6n-Ihzw"
}