// Cadastro de Produto + Variações (dev tool, auth User).
// Transação única: cria/atualiza Detalhe quando há variações, grava/atualiza o
// Produto (detalhe_id = 0 quando não há variações) e sincroniza as Variacao
// (cria sem id, edita com id, apaga as que não vieram no payload).
// Para Base_de_Calculo = COMPOSTO: regra de composição (ex.: "playkap")
// Fator de corte fixo do produto (prioridade 1 no M2). Preenchido → o cálculo usa
// direto; vazio → fallback Tipo_Fator (material+linha+borda).
query produto_cadastrar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int produto_id? {
      table = "Produto"
    }
  
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
  
    decimal valor?
    enum Unidade?=M2 {
      values = ["M2", "ML", "Und", "Kit"]
    }
  
    enum Base_de_Calculo?=M2 {
      values = ["M2", "ML", "KIT", "UND", "COMPOSTO"]
    }
  
    text tipo_composto? filters=trim
    bool com_medida_exata?
    decimal porcentagem_acrescimo?
    bool ativo?=true
    json[] variacoes?
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  }

  stack {
    var $detalhe_id {
      value = 0
    }
  
    // Resolve o detalhe atual do produto (para limpar variações órfãs quando não houver mais)
  
    var $detalhe_atual {
      value = 0
    }
  
    conditional {
      if ($input.produto_id != null) {
        db.get Produto {
          field_name = "id"
          field_value = $input.produto_id
        } as $Produto_existente
      
        var.update $detalhe_atual {
          value = $Produto_existente.detalhe_id|first_notnull:0
        }
      }
    }
  
    var $tem_variacoes {
      value = ($input.variacoes|count) > 0
    }
  
    // Validação: UND/KIT/ML exigem valor de custo = 0 (o produto não precisa ter 
    // valor base, pois u custo deste material estará obrifgatoriamente na variação).
  
    var $base_calculo_upper {
      value = $input.Base_de_Calculo|to_upper
    }
  
    !var $precisa_custo_base {
      value = $base_calculo_upper == "UND" || $base_calculo_upper == "KIT" || $base_calculo_upper == "ML"
    }
  
    !precondition (!$precisa_custo_base || $input.valor > 0) {
      error_type = "badrequest"
      error = "Produto sem custo base (valor). Informe o custo do produto — a variação herda quando não informado."
    }
  
    db.transaction {
      stack {
        // 1. Cria um Detalhe quando o produto tem variações e ainda não possui um
      
        conditional {
          if ($tem_variacoes && ($detalhe_atual == 0)) {
            db.add Detalhe {
              enforce_hidden_fields = false
              data = {Descricao: "", created_at: "now"}
            } as $novo_detalhe
          
            var.update $detalhe_id {
              value = $novo_detalhe.id
            }
          
            var.update $detalhe_atual {
              value = $novo_detalhe.id
            }
          }
        
          else {
            var.update $detalhe_id {
              value = $detalhe_atual
            }
          }
        }
      
        // 2. Grava/atualiza o Produto
      
        var $produto_salvo {
          value = null
        }
      
        conditional {
          if ($input.produto_id != null) {
            db.edit Produto {
              field_name = "id"
              field_value = $input.produto_id
              enforce_hidden_fields = false
              data = {
                material_id          : $input.material_id
                classificacao_id     : $input.classificacao_id
                linha_id             : $input.linha_id
                tipo_id              : $input.tipo_id
                nivel_id             : $input.nivel_id
                valor                : $input.valor
                Unidade              : $input.Unidade
                Base_de_Calculo      : $input.Base_de_Calculo
                tipo_composto        : $input.tipo_composto
                com_medida_exata     : $input.com_medida_exata
                porcentagem_acrescimo: $input.porcentagem_acrescimo
                detalhe_id           : $detalhe_id
                fator_de_corte_id    : $input.fator_de_corte_id
                ativo                : $input.ativo
              }
            } as $produto_editado
          
            var.update $produto_salvo {
              value = $produto_editado
            }
          }
        
          else {
            db.add Produto {
              enforce_hidden_fields = false
              data = {
                material_id          : $input.material_id
                classificacao_id     : $input.classificacao_id
                linha_id             : $input.linha_id
                tipo_id              : $input.tipo_id
                nivel_id             : $input.nivel_id
                valor                : $input.valor
                Unidade              : $input.Unidade
                Base_de_Calculo      : $input.Base_de_Calculo
                tipo_composto        : $input.tipo_composto
                com_medida_exata     : $input.com_medida_exata
                porcentagem_acrescimo: $input.porcentagem_acrescimo
                detalhe_id           : $detalhe_id
                fator_de_corte_id    : $input.fator_de_corte_id
                ativo                : $input.ativo
                created_at           : "now"
              }
            } as $produto_criado
          
            var.update $produto_salvo {
              value = $produto_criado
            }
          }
        }
      
        // 3. Sincroniza variações
        var $ids_payload {
          value = []
        }
      
        // Captura as variações pré-existentes do detalhe ANTES do loop de criação,
        // para o sync-delete apagar só as que não vieram no payload (a nova variação
        // criada aqui não pode ser candidata a exclusão).
      
        var $vars_antigas {
          value = []
        }
      
        var $ids_antigos {
          value = []
        }
      
        conditional {
          if ($tem_variacoes) {
            db.query Variacao {
              where = $db.Variacao.detalhe_id == $detalhe_id
              return = {type: "list"}
            } as $vars_antigas
          }
        }
      
        foreach ($vars_antigas) {
          each as $va {
            var.update $ids_antigos {
              value = $ids_antigos|append:$va.id
            }
          }
        }
      
        conditional {
          if ($tem_variacoes) {
            foreach ($input.variacoes) {
              each as $v {
                var $v_id {
                  value = $v|get:"id"
                }
              
                var $v_tipo_variacao_id {
                  value = $v|get:"tipo_variacao_id"
                }
              
                var $v_comp {
                  value = $v|get:"comp":0
                }
              
                var $v_larg {
                  value = $v|get:"larg":0
                }
              
                var $v_modelo_id {
                  value = $v|get:"modelo_id"
                }
              
                var $v_lxc {
                  value = $v|get:"LxC":""
                }
              
                var $v_qtd_kit {
                  value = $v|get:"qtd_kit":0
                }
              
                var $v_valor_custo {
                  value = $v|get:"valor_custo":0
                }
              
                // Herança de custo: variação sem valor_custo (0/nulo) herda o custo base do produto
              
                conditional {
                  if ($v_valor_custo == 0) {
                    var.update $v_valor_custo {
                      value = $input.valor
                    }
                  }
                }
              
                var $v_cor_id {
                  value = $v|get:"cor_id"
                }
              
                var $v_fator_de_corte {
                  value = $v|get:"fator_de_corte":0
                }
              
                var $v_fator_de_corte_id {
                  value = $v|get:"fator_de_corte_id"
                }
              
                var $v_ordem {
                  value = $v|get:"ordem":0
                }
              
                var $v_ativo {
                  value = $v|get:"ativo":true
                }
              
                conditional {
                  if ($v_id != null) {
                    var.update $ids_payload {
                      value = $ids_payload|append:$v_id
                    }
                  }
                }
              
                conditional {
                  if ($v_id != null) {
                    db.edit Variacao {
                      field_name = "id"
                      field_value = $v_id
                      enforce_hidden_fields = false
                      data = {
                        detalhe_id       : $detalhe_id
                        tipo_variacao_id : $v_tipo_variacao_id
                        comp             : $v_comp
                        larg             : $v_larg
                        modelo_id        : $v_modelo_id
                        LxC              : $v_lxc
                        qtd_kit          : $v_qtd_kit
                        valor_custo      : $v_valor_custo
                        cor_id           : $v_cor_id
                        fator_de_corte   : $v_fator_de_corte
                        fator_de_corte_id: $v_fator_de_corte_id
                        ordem            : $v_ordem
                        ativo            : $v_ativo
                      }
                    } as $var_editada
                  }
                
                  else {
                    db.add Variacao {
                      enforce_hidden_fields = false
                      data = {
                        detalhe_id       : $detalhe_id
                        tipo_variacao_id : $v_tipo_variacao_id
                        comp             : $v_comp
                        larg             : $v_larg
                        modelo_id        : $v_modelo_id
                        LxC              : $v_lxc
                        qtd_kit          : $v_qtd_kit
                        valor_custo      : $v_valor_custo
                        cor_id           : $v_cor_id
                        fator_de_corte   : $v_fator_de_corte
                        fator_de_corte_id: $v_fator_de_corte_id
                        ordem            : $v_ordem
                        ativo            : $v_ativo
                        created_at       : "now"
                      }
                    } as $var_criada
                  
                    // Marca a nova variação como "presente" para o sync-delete preservá-la
                  
                    var.update $ids_payload {
                      value = $ids_payload|append:$var_criada.id
                    }
                  }
                }
              }
            }
          
            // Remove variações antigas do detalhe que não vieram no payload.
            // Usa a lista capturada ANTES do loop ($ids_antigos): a nova variação
            // criada acima não é candidata a exclusão.
          
            foreach ($ids_antigos) {
              each as $ia {
                conditional {
                  if (($ids_payload|count) == 0 || ($ids_payload|in:$ia)|not) {
                    db.del Variacao {
                      field_name = "id"
                      field_value = $ia
                    }
                  }
                }
              }
            }
          }
        
          else {
            // Sem variações: apaga variações órfãs do detalhe anterior
          
            conditional {
              if ($detalhe_atual != 0) {
                db.query Variacao {
                  where = $db.Variacao.detalhe_id == $detalhe_atual
                  return = {type: "list"}
                } as $vars_orfas
              
                foreach ($vars_orfas) {
                  each as $vo {
                    db.del Variacao {
                      field_name = "id"
                      field_value = $vo.id
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  
    // Retorna o produto salvo (com variações) para o front renderizar
  
    db.query Produto {
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
      }
    
      where = $db.Produto.id == $produto_salvo.id
      eval = {
        descricao    : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome
        produto_id   : $db.Produto.id
        material_nome: $db.Material.nome
        linha_nome   : $db.Linha.nome
        tipo_nome    : $db.Tipo.nome
        nivel_nome   : $db.Nivel.nome
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
        "detalhe_id"
        "com_medida_exata"
        "porcentagem_acrescimo"
        "ativo"
        "descricao"
        "produto_id"
        "material_nome"
        "linha_nome"
        "tipo_nome"
        "nivel_nome"
      ]
    
      addon = [
        {
          name : "Variacao_of_Detalhe"
          input: {detalhe_id: $output.detalhe_id}
          as   : "_variacao"
        }
      ]
    } as $produto_final
  }

  response = {
    produto_id: $produto_salvo.id
    produto   : $produto_final|first
  }

  guid = "OrcaKap-produto-cadastrar-dev"
}