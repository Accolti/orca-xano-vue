// Rotina de Lote para reprocessar múltiplos orçamentos por intervalo de IDs
query Recalcula_Dados_em_Orcamento_e_item verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id_inicio
    int orca_id_fim
  }

  stack {
    // 1. Busca todos os orçamentos dentro do range informado
  
    db.query Orca {
      where = $db.Orca.id >= $input.orca_id_inicio && $db.Orca.id <= $input.orca_id_fim
      sort = {Orca.id: "asc"}
      return = {type: "list"}
    } as $lista_orcamentos
  
    // Array acumulador para construir o relatório final do lote
  
    var $relatorio_processamento {
      value = []
    }
  
    // 2. LOOPING EXTERNO: Percorre cada orçamento do intervalo
  
    foreach ($lista_orcamentos) {
      each as $Orca_Atual {
        // Busca todos os itens pertencentes ao orçamento atual
      
        db.query item {
          where = $db.item.orca_id == $Orca_Atual.id
          sort = {item.id: "asc"}
          return = {type: "list"}
        } as $itens_do_orcamento
      
        // Transação isolada: garante consistência por orçamento
      
        db.transaction {
          stack {
            // 3. LOOPING INTERNO: Recalcula e edita item por item
          
            foreach ($itens_do_orcamento) {
              each as $dados {
                // Executa orquestrador para calcular unitários isolados
              
                function.run f_Orcamento_Orquestrador {
                  input = {
                    produto_id         : $dados.produto_id
                    borda_id           : $dados.borda_id
                    variacao_id        : $dados.variacao_id
                    comprimento_ou_area: $dados.comp
                    largura            : $dados.larg
                    quantidade         : $dados.qtd
                    markup             : $Orca_Atual.margem
                    user_id            : $Orca_Atual.user_id
                    orca_id            : 0
                  }
                } as $Calc
              
                // Grava a foto atualizada no banco de dados
              
                db.edit item {
                  field_name = "id"
                  field_value = $dados.id
                  enforce_hidden_fields = false
                  data = {
                    ipi                  : $Calc.ipi
                    vlr_custo            : $Calc.vlr_cst_materia_prima
                    und_produto          : $Calc.base_calculo|to_upper
                    margem               : $Calc.margem
                    qtd                  : $Calc.qtd
                    vlr_vnd_unit         : $Calc.vlr_vnd_unit
                    vlr_lucro_unit       : $Calc.vlr_lucro_unit
                    vlr_vnd_unit_b2b     : $Calc.vlr_vnd_unit
                    vlr_cst_nota_unit    : $Calc.vlr_cst_nota_unit|default($Calc.vlr_custo_nota_unit)
                    vlr_cst_entrada_unit : $Calc.vlr_cst_entrada_unit
                    valor_difal_unit     : $Calc.vlr_difal_unit
                    vlr_credito_icms_unit: $Calc.vlr_credito_icms_unit
                    aliq_inter           : $Calc.vlr_aliq_inter
                    aliq_interna         : $Calc.vlr_aliq_interna
                    perc_difal           : $Calc.vlr_perc_difal
                    vlr_frete_b2b_unit   : $Calc.frete_b2b
                    vlr_st_unit          : $Calc.vlr_st_unit
                    vlr_custo_fiscal_unit: $Calc.vlr_custo_fiscal_unit
                    eh_importado         : $Calc.eh_importado
                    perc_margem_real     : $Calc.perc_margem_real
                  }
                } as $itemS
              }
            }
          
            // Consolida totais, rateia frete Kapazi e atualiza o cabeçalho Orca
          
            function.run Orcamento_Recalcular_Totais {
              input = {orca_id: $Orca_Atual.id, newMargem: $Orca_Atual.margem}
            } as $func1
          
            // Acumula o resultado no relatório geral
          
            var.update $relatorio_processamento {
              value = $relatorio_processamento
                |push:```
                  {
                    orca_id : $Orca_Atual.id,
                    totais  : $func1.totais,
                    status  : "Sucesso"
                  }
                  ```
            }
          }
        }
      }
    }
  }

  response = {
    total_processados: $relatorio_processamento|count
    resumo_lote      : $relatorio_processamento
  }

  guid = "HMMuxpf3uYWz5Vp34v-OC7faji8"
}