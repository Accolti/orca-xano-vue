function tes {
  input {
    int produto_id? {
      table = "Produto"
    }
  
    int borda_id? {
      table = "Borda"
    }
  
    int variacao_id? {
      table = "Variacao"
    }
  }

  stack {
    !function.run f_buscador_produto {
      input = {
        produto_id : $input.produto_id
        borda_id   : $input.borda_id
        variacao_id: $input.variacao_id
      }
    } as $func2
  
    !function.run "" {
      input = {
        comprimento: 2
        largura    : 0.45
        quantidade : 15
        prd        : $func2
      }
    } as $func1
  
    !function.run f_valor_custo_ml {
      input = {comprimento_ou_area: 10, largura: 5, produto: $func2}
    } as $func1
  
    !debug.stop {
      value = $func2
    }
  
    !db.query Material {
      where = $db.Material.st == true
      return = {type: "list"}
    } as $Material1
  
    !foreach ($Material1) {
      each as $item {
        db.edit Material {
          field_name = "id"
          field_value = $item.id
          data = {regra_fiscal_id: 2}
        } as $Material2
      }
    }
  
    !db.query Material {
      join = {
        Produto       : {
          table: "Produto"
          type : "left"
          where: $db.Material.id == $db.Produto.material_id
        }
        Variacao      : {
          table: "Variacao"
          type : "left"
          where: $db.Produto.detalhe_id == $db.Variacao.detalhe_id
        }
        Tipo_Fator    : {
          table: "Tipo_Fator"
          type : "left"
          where: $db.Tipo_Fator.material_id == $db.Produto.material_id
        }
        Fator_de_Corte: {
          table: "Fator_de_Corte"
          type : "left"
          where: $db.Fator_de_Corte.id == $db.Tipo_Fator.fator_de_corte_id
        }
      }
    
      where = $db.Produto.id != null && $db.Variacao.id == null && $db.Produto.Base_de_Calculo == "M2" && $db.Fator_de_Corte.id != null && $db.Produto.id == 63
      eval = {
        produto_id    : $db.Produto.id
        detalhe_id    : $db.Produto.detalhe_id
        variacao_id   : $db.Variacao.id
        tipo_fator_id : $db.Tipo_Fator.id
        fator_corte_id: $db.Fator_de_Corte.id
      }
    
      return = {type: "list"}
      output = [
        "id"
        "nome"
        "ativo"
        "produto_id"
        "detalhe_id"
        "variacao_id"
        "tipo_fator_id"
        "fator_corte_id"
      ]
    
      addon = [
        {
          name : "Fator_de_Corte_1"
          input: {Fator_de_Corte_id: $output.fator_corte_id}
          as   : "_fator_de_corte"
        }
      ]
    } as $Material1
  
    !db.query Material {
      where = $db.Material.id == 3
      return = {type: "list"}
    } as $Material1|first
  
    db.query User {
      where = $db.User.id == 9
      return = {type: "list"}
    } as $User1
  }

  response = {Material1: $User1}
  guid = "bO6cJwZN8ZwIrYM8_Fi5Vjw4iis"
}