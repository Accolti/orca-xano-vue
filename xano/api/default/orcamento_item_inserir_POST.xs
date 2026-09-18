// Inserir Orcamento e Itens
query OrcamentoItem_Inserir verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    // Número do orçamento (texto) — usado apenas quando o orçamento ainda não existe (1º item).
    text cod_orca? filters=trim
  
    // ID da Orca — preferido quando o orçamento já existe (2º+ item e edição).
    int orca_id? {
      table = "Orca"
    }
  
    int cliente_id? {
      table = "Cliente"
    }
  
    decimal frtB2B?
    decimal frtB2C?
    date? validade?
    decimal margem?
  
    // Observações gerais do orçamento (cabeçalho ORCA)
    text observacao? filters=trim
  
    int produto_id? {
      table = "Produto"
    }
  
    decimal ipi?
    decimal imp?
    decimal vlr_custo?
    text base_calculo? filters=trim
    text und_produto? filters=trim
    decimal larg?
    decimal comp?
    decimal larg_fc?
    decimal comp_fc?
    int borda_id? {
      table = "Borda"
    }
  
    decimal vlr_cst_borda?
    text und_borda? filters=trim
    int tipo_fator_id? {
      table = "Tipo_Fator"
    }
  
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  
    int detalhe_id? {
      table = "Detalhe"
    }
  
    int variacao_id? {
      table = "Variacao"
    }
  
    decimal qtd?
    decimal vlr_cst_unit?
    decimal vlr_cst_unit_ipi?
    decimal vlr_cst_unit_imp?
    decimal vlr_vnd_unit?
    decimal vlr_vnd_unit_ipi?
    decimal vlr_vnd_unit_imp?
    decimal vlr_vnd_unit_b2b?
    decimal vlr_lucro_unit?
    text descricao? filters=trim
    decimal area_user?
    decimal area_calc?
  
    // Campos Fiscais e de Custo Unitários conforme novo Schema
    decimal vlr_cst_nota_unit?
  
    decimal vlr_cst_entrada_unit?
    decimal valor_difal_unit?
    decimal vlr_credito_icms_unit?
    decimal aliq_inter?
    decimal aliq_interna?
    decimal perc_difal?
    decimal vlr_frete_b2b_unit?
    decimal vlr_st_unit?
    decimal vlr_custo_fiscal_unit?
    bool eh_importado?
    decimal perc_margem_real?
  
    // Medida exata (marcada pelo vendedor) — acréscimo já aplicado no custo pelo orquestrador
    bool com_medida_exata?
  
    decimal porcentagem_acrescimo?
  
    // array com os fatores de corte
    decimal[] fc?
  
    // Detalhes do cálculo (produtos compostos/ML) em JSON
    json detalhes_calculo?
  }

  stack {
    // Reforço: bloqueia quem foi desativado (o próprio ou um "pai") após o login
    function.run f_ativo_efetivo {
      input = {user_id: $auth.id}
    } as $ativoEfetivo
  
    precondition ($ativoEfetivo) {
      error_type = "accessdenied"
      error = "Conta inativa. Fale com o administrador."
    }
  
    var $id_orca {
      value = 0
    }
  
    // Resolve a Orca por precedência: orca_id (já existe) > cod_orca SOMENTE do próprio
    // usuário (cria no 1º item). Códigos podem se repetir entre contas — o fallback por
    // cod_orca nunca pode buscar global (risco de pegar Orca de outro usuário).
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id|first_notnull:0
    } as $Orca_0
  
    conditional {
      if (($Orca_0 == null) && ($input.cod_orca != null)) {
        db.query Orca {
          where = $db.Orca.cod_orca == $input.cod_orca && $db.Orca.user_id == $auth.id
          return = {type: "single"}
        } as $Orca_0
      }
    }
  
    var $pedidoBloqueado {
      value = false
    }
  
    conditional {
      if ($Orca_0 != null) {
        var.update $pedidoBloqueado {
          value = ($Orca_0.eh_pedido == true)
        }
      }
    }
  
    precondition ($pedidoBloqueado != true) {
      error_type = "badrequest"
      error = "Orçamento convertido em pedido. Edição bloqueada."
    }
  
    // Config efetiva (empresa): filhos herdam regime/UF/organização do topo (admin).
    // Sem isso, um orçamento criado por filho gravava regime_id=0 e uf_destino="".
    function.run f_perfil_efetivo {
      input = {user_id: $auth.id}
    } as $PerfilEfet
  
    db.query Organizacao {
      where = $db.Organizacao.id == $PerfilEfet.organizacao_id
      return = {type: "list"}
    } as $OrgEfet
  
    var $uf_origem {
      value = "PR"
    }
  
    var $primeira_org {
      value = $OrgEfet|first
    }
  
    conditional {
      if ($primeira_org != null) {
        var.update $uf_origem {
          value = $primeira_org.uf|first_notnull:"PR"
        }
      }
    }
  
    var $uf_destino {
      value = $PerfilEfet.uf
    }
  
    !debug.stop {
      value = $uf_origem
    }
  
    db.transaction {
      stack {
        // Se não existe orçamento para o código informado, cria um novo
        conditional {
          if ($Orca_0|is_null) {
            function.run post_orca {
              input = {
                cod_orca            : $input.cod_orca
                cliente_id          : $input.cliente_id
                frtB2B              : $input.frtB2B
                frtB2C              : $input.frtB2C
                validade            : $input.validade
                user_id             : $auth.id
                margem              : $input.margem
                desconto            : 0
                status              : "RASCUNHO"
                eh_pedido           : false
                regime_id           : $PerfilEfet.regime_id
                uf_origem           : $uf_origem
                uf_destino          : $uf_destino
                markup_alvo         : $input.margem
                motivo_recusa       : ""
                vlr_st_tot          : 0
                vlr_ipi_tot         : 0
                valor_difal_tot     : 0
                vlr_credito_icms_tot: 0
                vlr_custo_fiscal_tot: 0
                total_itens         : 0
                data_aprovacao      : null
                data_envio          : null
              }
            } as $orca_1
          
            var.update $id_orca {
              value = $orca_1.id
            }
          
            !debug.stop {
              value = $uf_origem
            }
          }
        
          else {
            var.update $id_orca {
              value = $Orca_0.id
            }
          
            var $orca_1 {
              value = $Orca_0
            }
          
            // Atualiza a observação no cabeçalho existente e limpa as condições de
            // pagamento (ficam desatualizadas quando o conjunto de itens muda)
            db.edit Orca {
              field_name = "id"
              field_value = $Orca_0.id
              enforce_hidden_fields = false
              data = {observacao: $input.observacao, condicoes_pagamento: ""}
            } as $Orca_editada
          }
        }
      
        db.transaction {
          stack {
            function.run post_item {
              input = {
                orca_id              : $id_orca
                produto_id           : $input.produto_id
                ipi                  : $input.ipi
                imp                  : $input.imp
                vlr_custo            : $input.vlr_custo
                base_calculo         : $input.base_calculo
                und_produto          : $input.und_produto
                larg                 : $input.larg
                comp                 : $input.comp
                larg_fc              : $input.larg_fc
                comp_fc              : $input.comp_fc
                borda_id             : $input.borda_id
                vlr_cst_borda        : $input.vlr_cst_borda
                und_borda            : $input.und_borda
                tipo_fator_id        : $input.tipo_fator_id
                detalhe_id           : $input.detalhe_id
                fator_de_corte_id    : $input.fator_de_corte_id
                variacao_id          : $input.variacao_id
                margem               : $input.margem
                qtd                  : $input.qtd
                vlr_cst_unit         : $input.vlr_cst_unit
                vlr_cst_unit_ipi     : $input.vlr_cst_unit_ipi
                vlr_cst_unit_imp     : $input.vlr_cst_unit_imp
                vlr_vnd_unit         : $input.vlr_vnd_unit
                vlr_vnd_unit_ipi     : $input.vlr_vnd_unit_ipi
                vlr_vnd_unit_imp     : $input.vlr_vnd_unit_imp
                vlr_lucro_unit       : $input.vlr_lucro_unit
                vlr_vnd_unit_b2b     : $input.vlr_vnd_unit_b2b
                descricao            : $input.descricao
                area_user            : $input.area_user
                area_calc            : $input.area_calc
                vlr_cst_nota_unit    : $input.vlr_cst_nota_unit
                vlr_cst_entrada_unit : $input.vlr_cst_entrada_unit
                valor_difal_unit     : $input.valor_difal_unit
                vlr_credito_icms_unit: $input.vlr_credito_icms_unit
                aliq_inter           : $input.aliq_inter
                aliq_interna         : $input.aliq_interna
                perc_difal           : $input.perc_difal
                vlr_frete_b2b_unit   : $input.vlr_frete_b2b_unit
                vlr_st_unit          : $input.vlr_st_unit
                vlr_custo_fiscal_unit: $input.vlr_custo_fiscal_unit
                eh_importado         : $input.eh_importado
                perc_margem_real     : $input.perc_margem_real
                com_medida_exata     : $input.com_medida_exata
                porcentagem_acrescimo: $input.porcentagem_acrescimo
                fc                   : $input.fc
                detalhes_calculo     : $input.detalhes_calculo
              }
            } as $func_2
          }
        }
      }
    }
  
    // Recálculo dinâmico por somatório — consolida os unitários na tabela Orca (_tot)
    function.run Orcamento_Recalcular_Totais {
      input = {orca_id: $id_orca}
    } as $func_1
  }

  response = {
    orca_1: $orca_1
    func_2: $func_2
    ORC   : ```
      {
        ORCA_1: $func_1.ORCA_1
        itemS : $func_1.itemS
      }
      ```
  }

  guid = "fjoyzyS1PAc_8DAFK05TD9-BOyU"
}