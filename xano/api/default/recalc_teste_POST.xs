query Recalc_teste verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    decimal newMargem?
  }

  stack {
    function.run Orcamento_Recalcular_Totais {
      input = {orca_id: $input.orca_id, newMargem: $input.newMargem}
    } as $func1
  }

  response = $func1
  guid = "NItu_8cPdvuXAsfmQBl_3A2XhWk"
}