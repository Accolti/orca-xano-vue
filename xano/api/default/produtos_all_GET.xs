query produtos_all verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int produto_id? {
      table = "Produto"
    }
  
    int material_id? {
      table = "Material"
    }
  
    int linha_id? {
      table = "Linha"
    }
  
    int tipo_id? {
      table = "Tipo"
    }
  
    int nivel_id? {
      table = "Nivel"
    }
  
    int detalhe_id? {
      table = "Detalhe"
    }
  }

  stack {
    function.run fTodos_Produtos {
      input = {
        produto_id : $input.produto_id
        material_id: $input.material_id
        linha_id   : $input.linha_id
        tipo_id    : $input.tipo_id
        nivel_id   : $input.nivel_id
        borda_id   : $input.borda_id
        detalhe_id : $input.detalhe_id
      }
    } as $func1
  }

  response = $func1
  guid = "Wm2j8XXblxSwxzJyUY4FHWZ2dmM"
}