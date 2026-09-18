// Retorna o frete b2b 
query Frete_b2b verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    decimal valor_total_compra?
  }

  stack {
    function.run fCalculaFrete {
      input = {
        valor_total_compra: $input.valor_total_compra
        user_id           : $auth.id
      }
    } as $frete_b2b
  }

  response = $frete_b2b
  guid = "ZJSMxBRQSRnzPKNE-0tSyLXvVro"
}