// Este módulo vai buscar  o produto e trazer suas variantes se tiver
function f_buscador_produto {
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
    db.query Produto {
      join = {
        Material    : {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id && $db.Material.ativo == true
        }
        Linha       : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo        : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel       : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Nivel.id
        }
        Borda       : {
          table: "Borda"
          type : "left"
          where: $db.Borda.material_id ==? $db.Material.id && $db.Borda.ativo ==? true
        }
        Detalhe     : {
          table: "Detalhe"
          type : "left"
          where: $db.Produto.detalhe_id ==? $db.Detalhe.id
        }
        Variacao    : {
          table: "Variacao"
          type : "left"
          where: $db.Detalhe.id ==? $db.Variacao.detalhe_id
        }
        Regra_Fiscal: {
          table: "Regra_Fiscal"
          type : "left"
          where: $db.Material.regra_fiscal_id ==? $db.Regra_Fiscal.id
        }
      }
    
      where = $db.Produto.id ==? $input.produto_id && ($db.Borda.id ==? $input.borda_id && $db.Variacao.id ==? $input.variacao_id)
      eval = {
        borda_id       : $db.Borda.id
        borda_nome     : $db.Borda.nome
        borda_valor    : $db.Borda.valor
        borda_unidade  : $db.Borda.Unidade
        material_nome  : $db.Material.nome
        linha_nome     : $db.Linha.nome
        tipo_nome      : $db.Tipo.nome
        nivel_nome     : $db.Nivel.nome
        ncm            : $db.Material.ncm
        imp            : $db.Material.imp
        ipi            : $db.Material.ipi
        variacao_id    : $db.Variacao.id
        variacao_custo : $db.Variacao.valor_custo
        variacao_fc_id : $db.Variacao.fator_de_corte_id
        eh_importado   : $db.Material.importado
        st             : $db.Regra_Fiscal.tem_st
        mva_padrao     : $db.Regra_Fiscal.mva_padrao
        aliq_st_interna: $db.Regra_Fiscal.aliq_st_interna
      }
    
      return = {type: "list"}
      output = [
        "id"
        "material_id"
        "classificacao_id"
        "linha_id"
        "tipo_id"
        "nivel_id"
        "valor"
        "com_medida_exata"
        "porcentagem_acrescimo"
        "Unidade"
        "Base_de_Calculo"
        "tipo_composto"
        "created_at"
        "detalhe_id"
        "fator_de_corte_id"
        "ativo"
        "borda_id"
        "borda_nome"
        "borda_valor"
        "borda_unidade"
        "material_nome"
        "linha_nome"
        "tipo_nome"
        "nivel_nome"
        "ncm"
        "imp"
        "ipi"
        "variacao_id"
        "variacao_custo"
        "variacao_fc_id"
        "eh_importado"
        "st"
        "mva_padrao"
        "aliq_st_interna"
      ]
    
      addon = [
        {
          name : "Variacao"
          input: {Variacao_id: $input.variacao_id}
          addon: [
            {
              name : "fator_de_corte_variacao"
              input: {variacao_id: $input.variacao_id}
              as   : "_fator_de_corte_variacao"
            }
          ]
          as   : "_variacao"
        }
      ]
    } as $Produto1
  
    !db.query Produto {
      join = {
        Material: {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Linha   : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo    : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel   : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Nivel.id
        }
        Borda   : {
          table: "Borda"
          type : "left"
          where: $db.Borda.material_id ==? $db.Material.id && $db.Borda.ativo ==? true
        }
        Detalhe : {
          table: "Detalhe"
          type : "left"
          where: $db.Produto.detalhe_id ==? $db.Detalhe.id
        }
        Variacao: {
          table: "Variacao"
          type : "left"
          where: $db.Detalhe.id ==? $db.Variacao.detalhe_id
        }
      }
    
      where = $db.Produto.id ==? $input.produto_id && ($db.Borda.id == $input.borda_id || $db.Variacao.id == $input.variacao_id)
      eval = {
        borda_id      : $db.Borda.id
        borda_nome    : $db.Borda.nome
        borda_valor   : $db.Borda.valor
        borda_unidade : $db.Borda.Unidade
        material_nome : $db.Material.nome
        linha_nome    : $db.Linha.nome
        tipo_nome     : $db.Tipo.nome
        nivel_nome    : $db.Nivel.nome
        ncm           : $db.Material.ncm
        imp           : $db.Material.imp
        ipi           : $db.Material.ipi
        variacao_id   : $db.Variacao.id
        variacao_custo: $db.Variacao.valor_custo
        variacao_fc_id: $db.Variacao.fator_de_corte_id
        eh_importado  : $db.Material.importado
      }
    
      return = {type: "list"}
      output = [
        "id"
        "material_id"
        "classificacao_id"
        "linha_id"
        "tipo_id"
        "nivel_id"
        "valor"
        "Unidade"
        "Base_de_Calculo"
        "created_at"
        "detalhe_id"
        "borda_id"
        "borda_nome"
        "borda_valor"
        "borda_unidade"
        "material_nome"
        "linha_nome"
        "tipo_nome"
        "nivel_nome"
        "ncm"
        "imp"
        "ipi"
        "variacao_id"
        "variacao_custo"
        "variacao_fc_id"
        "eh_importado"
      ]
    
      addon = [
        {
          name : "Variacao"
          input: {Variacao_id: $input.variacao_id}
          addon: [
            {
              name : "fator_de_corte_variacao"
              input: {variacao_id: $input.variacao_id}
              as   : "_fator_de_corte_variacao"
            }
          ]
          as   : "_variacao"
        }
      ]
    } as $Produto1
  
    // Verifica se os IDs necessários foram enviados. Como podem vir como Hashids (strings), usamos null checks.
  
    !precondition (($input.produto_id != null && $input.borda_id != null) || ($input.produto_id != null && $input.variacao_id != null)) {
      error = "Obrigatorio ter produto_id e borda_id OU produto_id e variacao_id"
    }
  
    !precondition ($input.produto_id == null || $input.borda_id == null || $input.variacao_id == null) {
      error = "Não é permitido enviar produto_id, borda_id e variacao_id simultaneamente"
    }
  
    // Garante que não foram enviados borda_id e variacao_id ao mesmo tempo.
  }

  response = $Produto1
  guid = "pczQWb8NugcmciXmBvgs-LbmoLg"
}