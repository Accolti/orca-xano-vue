query Orcamento_Detalhes verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text orca_codigo? filters=trim
    decimal newMargem?
  }

  stack {
    var $numero_Orc {
      value = $input.orca_codigo|replace:"PED":"ORC"
    }
  
    !debug.stop {
      value = $numero_Orc
    }
  
    function.run Orcamento_Detalhes_Function {
      input = {
        orca_codigo: $numero_Orc
        newMargem  : $input.newMargem
        orca_id    : "0"
      }
    } as $func_1
  }

  response = $func_1
  guid = "-s9038d0Hm4qYDCtQ5-jscMnIl8"
}