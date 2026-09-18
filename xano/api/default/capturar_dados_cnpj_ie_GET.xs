query capturarDados_CNPJ_IE verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text cnpj? filters=trim
  }

  stack {
    function.run f_get_CNPJ {
      input = {cnpj: $input.cnpj}
    } as $func1
  }

  response = $func1
  guid = "9kHZ4wT5O2odpujZnn6y7A4KvNY"
}