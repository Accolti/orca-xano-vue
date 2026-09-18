query produtos_para_selecao_id verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    function.run f_produtos_selecao as $func1
  }

  response = {lista_para_selecao: $func1}
  guid = "f3NBjwa_IEwxiDCtFbzB4_wTSCo"
}