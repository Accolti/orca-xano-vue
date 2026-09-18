// novo-sis: leitura read-only de um orçamento a partir do cod_orca.
// Retorna ORCA_1 (com _cliente) e itemS (com Descricao + campos fiscais).
// NÃO recalcula e NÃO escreve no banco — usado para abrir/editar sem custo.
query orca_detalhes verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text cod_orca? filters=trim
  }

  stack {
    // Resolve SEMPRE o do próprio usuário (códigos repetem entre contas)
  
    db.query Orca {
      where = $db.Orca.cod_orca == $input.cod_orca && $db.Orca.user_id == $auth.id
      return = {type: "single"}
      output = ["id"]
    } as $minha
  
    precondition ($minha != null) {
      error_type = "notfound"
      error = "Orçamento não encontrado para o seu usuário."
    }
  
    db.get Orca {
      field_name = "id"
      field_value = $minha.id
      addon = [
        {
          name : "Cliente"
          input: {Cliente_id: $output.cliente_id}
          addon: [
            {
              name  : "Telefone_Cliente_of_Cliente"
              output: [
                "id"
                "created_at"
                "cliente_id"
                "tipo_telefone_id"
                "telefone"
                "descricao"
              ]
              input : {cliente_id: $output.id}
              as    : "_telefone_cliente_of_cliente"
            }
          ]
          as   : "_cliente"
        }
        {
          name : "Endereco_Cliente"
          input: {cliente_id: $output.cliente_id}
          as   : "_enderecos"
        }
      ]
    } as $Orca_1
  
    db.query item {
      join = {
        Produto : {
          table: "Produto"
          where: $db.item.produto_id == $db.Produto.id
        }
        Material: {
          table: "Material"
          where: $db.Material.id == $db.Produto.material_id
        }
        Linha   : {
          table: "Linha"
          type : "left"
          where: $db.Linha.id ==? $db.Produto.linha_id
        }
        Tipo    : {
          table: "Tipo"
          type : "left"
          where: $db.Tipo.id ==? $db.Produto.tipo_id
        }
        Nivel   : {
          table: "Nivel"
          type : "left"
          where: $db.Nivel.id ==? $db.Produto.nivel_id
        }
        Borda   : {
          table: "Borda"
          type : "left"
          where: $db.Borda.id ==? $db.item.borda_id
        }
      }
    
      where = $db.item.orca_id == $Orca_1.id
      sort = {item.id: "asc"}
      eval = {
        Descricao  : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome|concat:" "|concat:$db.Borda.nome
        material_id: $db.Produto.material_id
        linha_id   : $db.Produto.linha_id
        tipo_id    : $db.Produto.tipo_id
        nivel_id   : $db.Produto.nivel_id
      }
    
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "orca_id"
        "produto_id"
        "material_id"
        "linha_id"
        "tipo_id"
        "nivel_id"
        "ipi"
        "imp"
        "vlr_custo"
        "und_produto"
        "larg"
        "comp"
        "larg_fc"
        "comp_fc"
        "borda_id"
        "vlr_cst_borda"
        "und_borda"
        "tipo_fator_id"
        "fator_de_corte_id"
        "detalhe_id"
        "variacao_id"
        "margem"
        "qtd"
        "vlr_cst_unit"
        "vlr_cst_unit_ipi"
        "vlr_cst_unit_imp"
        "vlr_vnd_unit"
        "vlr_vnd_unit_ipi"
        "vlr_vnd_unit_imp"
        "vlr_lucro_unit"
        "vlr_vnd_unit_b2b"
        "descricao"
        "area_user"
        "area_calc"
        "vlr_cst_nota_unit"
        "vlr_cst_entrada_unit"
        "valor_difal_unit"
        "vlr_credito_icms_unit"
        "aliq_inter"
        "aliq_interna"
        "perc_difal"
        "vlr_frete_b2b_unit"
        "vlr_st_unit"
        "vlr_custo_fiscal_unit"
        "eh_importado"
        "perc_margem_real"
        "com_medida_exata"
        "porcentagem_acrescimo"
        "vlr_vnd_unit_bruto"
        "Descricao"
        "detalhes_calculo"
      ]
    } as $itemS
  }

  response = {ORCA_1: $Orca_1, itemS: $itemS}
  tags = ["orcamento", "novo-sis"]
  guid = "orca-detalhes-novo-sis-0001"
}