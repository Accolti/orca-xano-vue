query Novo_Numero_Orcamento verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int id_do_Usuario?
  }

  stack {
    function.run Novo_Numero_Orcamento {
      input = {id_do_Usuario: $input.id_do_Usuario}
    } as $func_1
  }

  response = {result_1: $func_1}
  guid = "Z9KmdYn38ZMpiVYjAf4Bos_ab-Y"
}