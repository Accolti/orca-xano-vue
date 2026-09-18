// Query all Variacao records
query variacao_Id_Detalhe verb=GET {
  api_group = "Default"

  input {
    text Material? filters=trim
    text Classificacao? filters=trim
    text Linha? filters=trim
    text Tipo? filters=trim
    text Nivel? filters=trim
    text Borda? filters=trim
  }

  stack {
    db.query Produto {
      join = {
        Material     : {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Classificacao: {
          table: "Classificacao"
          where: $db.Produto.classificacao_id == $db.Classificacao.id
        }
        Linha        : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo         : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel        : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Linha.id
        }
        Variacao     : {
          table: "Variacao"
          where: $db.Produto.detalhe_id == $db.Variacao.detalhe_id
        }
      }
    
      where = ($db.Material.nome|to_upper) == ($input.Material|to_upper) && ($db.Classificacao.nome|to_upper) == ($input.Classificacao|to_upper) && ($db.Linha.nome|to_upper) ==? ($input.Linha|to_upper) && ($db.Tipo.nome|to_upper) ==? ($input.Tipo|to_upper) && ($db.Nivel.nome|to_upper) ==? ($input.Nivel|to_upper)
      return = {type: "list"}
    } as $Produto_1
  
    db.query Variacao {
      join = {
        Produto      : {
          table: "Produto"
          where: $db.Variacao.detalhe_id == $db.Produto.detalhe_id
        }
        Material     : {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Classificacao: {
          table: "Classificacao"
          where: $db.Produto.classificacao_id == $db.Classificacao.id
        }
        Linha        : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo         : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel        : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Nivel.id
        }
      }
    
      where = ($db.Material.nome|to_upper) == ($input.Material|to_upper) && ($db.Classificacao.nome|to_upper) == ($input.Classificacao|to_upper) && ($db.Linha.nome|to_upper) ==? ($input.Linha|to_upper) && ($db.Tipo.nome|to_upper) ==? ($input.Tipo|to_upper) && ($db.Nivel.nome|to_upper) ==? ($input.Nivel|to_upper)
      return = {type: "list"}
    } as $variacao
  }

  response = {Produto_1: $Produto_1, variacao: $variacao}
  guid = "l46tl2H75VIztpu62iVAtiA_6EA"
}