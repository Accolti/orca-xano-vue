// Only a test
query helloword verb=GET {
  api_group = "Teste"

  input {
    text firstName? filters=trim
    text lastName? filters=trim
  }

  stack {
    var $nomeCompleto {
      value = $input.firstName
        |concat:$input.lastName:" "
        |to_upper
    }
  
    array.has ([])
    foreach ([]) {
      each as $item
    }
  }

  response = $nomeCompleto
  guid = "OBOaY4X7FNUjr76gZryGVD5vaiY"
}