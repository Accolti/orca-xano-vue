// Conta as opções disponíveis (Linha, Tipo, Nivel, Borda, Variacao) de um material
// considerando a seleção atual de linha/tipo. Usado pelo frontend para esconder
// dropdowns que não fazem sentido para a combinação selecionada.
query produtos_suc_filtrado verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int material_id?
    int linha_id?
    int tipo_id?
    int organizacao_id?
  }

  stack {
    function.run Ret_Suc_Filtrado {
      input = {
        material_id   : $input.material_id
        linha_id      : $input.linha_id
        tipo_id       : $input.tipo_id
        organizacao_id: $input.organizacao_id
      }
    } as $func1
  }

  response = $func1
  guid = "2U5kgYysgm6Rv6ZXQOfEaA"
}