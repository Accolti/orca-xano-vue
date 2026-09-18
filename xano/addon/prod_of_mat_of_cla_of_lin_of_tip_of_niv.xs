addon Prod_of_Mat_of_Cla_of_Lin_of_Tip_of_Niv {
  input {
    int material_id? {
      table = "Material"
    }
  
    int classificacao_id? {
      table = "Classificacao"
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
  }

  stack {
    db.query Produto {
      where = $db.Produto.material_id == $input.material_id && $db.Produto.classificacao_id ==? $input.classificacao_id && $db.Produto.linha_id ==? $input.linha_id && $db.Produto.tipo_id ==? $input.tipo_id && $db.Produto.nivel_id ==? $input.nivel_id
      return = {type: "list"}
    }
  }

  guid = "UM1Ldwfyt8bUv2qoFlpMs8exVVg"
}