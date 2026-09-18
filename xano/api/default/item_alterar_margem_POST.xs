// Alterar a margem de todos os itens do orçamentp
query Item_alterar_margem verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    decimal margem?
  }

  stack {
    function.run Item_alterar_margem {
      input = {orca_id: $input.orca_id, margem: $input.margem}
    } as $func_1
  }

  response = $func_1
  guid = "z-yt-WPmLLxIr4KYm1Fzn_HL4PA"
}