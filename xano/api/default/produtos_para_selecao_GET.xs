query produtos_para_selecao verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    function.run f_produtos_selecao as $func1
  }

  response = {lista_para_selecao: $func1}
  guid = "HqNYI51BAZrberbCk5wko5DSVc0"
}