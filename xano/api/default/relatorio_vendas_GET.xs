query relatorio_vendas verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    date? dt_ini?
    date? dt_fin?
  }

  stack {
    function.run f_relatorio_recebidos {
      input = {
        dt_ini : $input.dt_ini
        dt_fin : $input.dt_fin
        user_id: $auth.id
      }
    } as $func1
  }

  response = $func1
  guid = "97qDQOnjg8DxY7oNjORfE6KyVHk"
}