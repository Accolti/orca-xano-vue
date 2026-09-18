// Leitura read-only de um orçamento pelo ID da Orca (auth).
// Visão: dono, ancestrais (pai/avô até admin) e admin_geral. Retorna ORCA_1 + itemS.
query orca_por_id verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
      output = ["id", "user_id"]
    } as $check
  
    precondition ($check != null) {
      error_type = "notfound"
      error = "Orçamento não encontrado."
    }
  
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "role", "vendedor_pai_id"]
    } as $viewer
  
    db.get User {
      field_name = "id"
      field_value = $check.user_id
      output = ["id", "role", "vendedor_pai_id"]
    } as $owner
  
    var $permitido {
      value = false
    }
  
    conditional {
      if (($viewer.role == "admin_geral") || ($check.user_id == $auth.id)) {
        var.update $permitido {
          value = true
        }
      }
    
      else {
        conditional {
          if (($owner.vendedor_pai_id != null) && ($owner.vendedor_pai_id > 0)) {
            conditional {
              if ($owner.vendedor_pai_id == $auth.id) {
                var.update $permitido {
                  value = true
                }
              }
            
              else {
                db.get User {
                  field_name = "id"
                  field_value = $owner.vendedor_pai_id
                  output = ["id", "role", "vendedor_pai_id"]
                } as $paiOwner
              
                conditional {
                  if (($paiOwner.role == "vendedor_master") && ($paiOwner.vendedor_pai_id == $auth.id)) {
                    var.update $permitido {
                      value = true
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  
    precondition ($permitido) {
      error_type = "accessdenied"
      error = "Você não tem acesso a este orçamento."
    }
  
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
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
    
      where = $db.item.orca_id == $input.orca_id
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
  guid = "orca-por-id-novo-sis-0001"
}