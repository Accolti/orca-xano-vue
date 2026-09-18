// Config efetiva (empresa dona) do usuário logado — para o front usar em PDF,
// previsão de markup/frete/validade e documentos (filhos herdam do pai).
query perfil_efetivo verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    function.run f_perfil_efetivo {
      input = {user_id: $auth.id}
    } as $perf
  }

  response = $perf
  tags = ["perfil", "hierarquia"]
  guid = "perfil-efetivo-get-f3-0001"
}