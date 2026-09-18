query Orca_Item verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text orca_codigo? filters=trim
  }

  stack {
    !db.query "" {
      join = {
        Produto : {
          table: "Produto"
          where: $db.Orcamento.produto_id == $db.Produto.id
        }
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
          where: $db.Orcamento.borda_id ==? $db.Borda.id
        }
      }
    
      where = $db.Orcamento.orca_codigo == $input.orca_codigo
      eval = {
        Descricao          : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome|concat:" "|concat:$db.Borda.nome
        valor_vnd_total_B2B: $db.Orcamento.valor_vnd_unit_b2b|mul:$db.Orcamento.qtd
        valor_cst_total    : $db.Orcamento.valor_cst_unit|mul:$db.Orcamento.qtd
        valor_lucro_total  : $db.Orcamento.valor_lucro_unit|mul:"Orcamento.qtd"
        valor_vnd_total    : $db.Orcamento.valor_vnd_unit|mul:"Orcamento.qtd"
      }
    
      return = {type: "list"}
      output = [
        "id"
        "orca_codigo"
        "item"
        "created_at"
        "produto_id"
        "valor_custo"
        "und_produto"
        "comp"
        "larg"
        "comp_fc"
        "larg_fc"
        "borda_id"
        "valor_custo_borda"
        "und_borda"
        "tipo_fator_id"
        "fator_de_corte_id"
        "margem"
        "frete_b2b"
        "frete_b2c"
        "valor_cst_unit"
        "valor_vnd_unit"
        "valor_lucro_unit"
        "valor_vnd_unit_b2b"
        "qtd"
        "und_qtd"
        "user_id"
        "Descricao"
        "valor_vnd_total_B2B"
        "valor_cst_total"
        "valor_lucro_total"
        "valor_vnd_total"
      ]
    } as $Orcamento_1
  
    db.query Orca {
      join = {
        item    : {table: "item", where: $db.Orca.id == $db.item.orca_id}
        Produto : {
          table: "Produto"
          where: $db.Produto.id == $db.item.produto_id
        }
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
          where: $db.item.borda_id ==? $db.Borda.id
        }
        Cliente : {
          table: "Cliente"
          type : "left"
          where: $db.Orca.cliente_id ==? $db.Cliente.id
        }
      }
    
      where = $db.Orca.cod_orca ==? $input.orca_codigo && $db.Orca.user_id == $auth.id
      sort = {Orca.created_at: "desc"}
      eval = {
        nome           : $db.Cliente.nome_fantasia|coalesce:$db.Cliente.razao_social
        CPF            : $db.Cliente.cpf
        CNPJ           : $db.Cliente.cnpj
        qtdItem        : $db.item.qtd
        vlr_venda_total: $db.item.vlr_vnd_unit_b2b
      }
    
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "cod_orca"
        "cliente_id"
        "frtB2B"
        "frtB2C"
        "validade"
        "user_id"
        "margem"
        "nome"
        "CPF"
        "CNPJ"
        "QtdItem"
        "Vlr_venda_Total"
      ]
    
      addon = [
        {
          name : "item_of_Orca"
          input: {orca_id: $output.id}
          as   : "_item_of_orca"
        }
      ]
    } as $Orca_1
  
    foreach ($Orca_1._item_of_orca) {
      each as $item
    }
  }

  response = $Orca_1
  guid = "RNLw5W7fDjHWVQ4H0TS0C5qt2jw"
}