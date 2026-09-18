// Cálculo fiscal: DIFAL, Crédito ICMS e ST conforme regime tributário do vendedor.
// Recebe o custo_nota (fábrica + IPI) e devolve o custo fiscal de entrada.
function Precificar {
  input {
    // Custo da nota fiscal (produto + IPI), já somado antes de chamar
    decimal custo_nota?
  
    // UF do fornecedor (organização). Ex.: "PR"
    text uf_origem? filters=trim|max:2
  
    // UF do vendedor (user.uf). Ex.: "SP"
    text uf_destino? filters=trim|max:2
  
    // "MEI" | "SIMPLES" | "LUCRO_REAL" | "LUCRO_PRESUMIDO"
    text regime_empresa? filters=trim
  
    int regime_id?
  
    // true se o produto for importado (alíquota interestadual 4%)
    bool eh_importado?
  
    // Parametros da Substituição Tributária (ST) vindos do Material
    bool tem_st?
  
    decimal mva_padrao?
    decimal aliq_st_interna?
  }

  stack {
    db.get Aliquotas_icms {
      field_name = "uf"
      field_value = $input.uf_destino
    } as $estado_destino
  
    db.get Aliquotas_icms {
      field_name = "uf"
      field_value = $input.uf_origem
    } as $estado_origem
  
    // Resolve o regime: se regime_id informado, busca o slug na tabela Regime
  
    var $regime {
      value = $input.regime_empresa|to_upper
    }
  
    conditional {
      if ($input.regime_id && $input.regime_id > 0) {
        db.get Regime {
          field_name = "id"
          field_value = $input.regime_id
        } as $regime_record
      
        var.update $regime {
          value = $regime_record.slug
        }
      }
    }
  
    // 1. Alíquota interestadual (12 padrão, 7 Sul/Sudeste -> demais, 4 importado)
  
    var $aliq_inter {
      value = 12
    }
  
    conditional {
      if ($input.eh_importado) {
        var.update $aliq_inter {
          value = 4
        }
      }
    
      else {
        conditional {
          if (($estado_origem.regiao|to_upper) == "SUL_SUDESTE" && ($estado_destino.regiao|to_upper) == "OUTROS") {
            var.update $aliq_inter {
              value = 7
            }
          }
        }
      }
    }
  
    // 2. Percentual e valor do DIFAL (só se interestadual)
  
    var $perc_difal {
      value = 0
    }
  
    var $valor_difal {
      value = 0
    }
  
    conditional {
      if (($input.uf_origem|to_upper) != ($input.uf_destino|to_upper)) {
        var $difal_bruto {
          value = $estado_destino.aliquota_modal|subtract:$aliq_inter
        }
      
        conditional {
          if ($difal_bruto > 0) {
            var.update $perc_difal {
              value = $difal_bruto
            }
          
            var.update $valor_difal {
              value = $input.custo_nota
                |multiply:($difal_bruto|divide:100)
                |round:2
            }
          }
        }
      }
    }
  
    // 3. Cálculo da Substituição Tributária (ST) - Para regimes não MEI
  
    var $valor_st {
      value = 0
    }
  
    // Se o material tem ST e o regime não for MEI, calcula o ST
    conditional {
      if ($input.tem_st && $regime != "MEI") {
        // Define a alíquota interna (usa a informada no Material ou cai na modal da UF Destino)
        var $aliq_st {
          value = $input.aliq_st_interna
        }
      
        conditional {
          if (!$aliq_st) {
            var.update $aliq_st {
              value = $estado_destino.aliquota_modal
            }
          }
        }
      
        // Base ST = Custo Nota * (1 + MVA%)
        var $base_st {
          value = $input.custo_nota
            |multiply:(1
              |add:($input.mva_padrao|divide:100)
            )
        }
      
        // ICMS ST Bruto = Base ST * Alíquota Interna
        var $icms_st_bruto {
          value = $base_st|multiply:($aliq_st|divide:100)
        }
      
        // ICMS Operação Própria = Custo Nota * Alíquota Interestadual
        var $icms_proprio {
          value = $input.custo_nota
            |multiply:($aliq_inter|divide:100)
        }
      
        // ST Líquida = ICMS ST Bruto - ICMS Próprio
        var $st_calculado {
          value = $icms_st_bruto|subtract:$icms_proprio|round:2
        }
      
        conditional {
          if ($st_calculado > 0) {
            var.update $valor_st {
              value = $st_calculado
            }
          }
        }
      }
    }
  
    // 4. Crédito ICMS e Custo Fiscal Consolidado por Regime
  
    var $credito_icms {
      value = 0
    }
  
    var $custo_fiscal {
      value = $input.custo_nota
    }
  
    // MEI/Simples: DIFAL e ST entram no Custo Fiscal
    // Lucro Real/Presumido: abate Crédito ICMS e soma ST
    conditional {
      if ($regime == "MEI" || $regime == "SIMPLES" || $regime == "SIMPLES_NACIONAL") {
        var.update $custo_fiscal {
          value = $input.custo_nota
            |add:$valor_difal
            |add:$valor_st
            |round:2
        }
      }
    
      else {
        var.update $credito_icms {
          value = $input.custo_nota
            |multiply:($aliq_inter|divide:100)
            |round:2
        }
      
        var.update $custo_fiscal {
          value = $input.custo_nota
            |subtract:$credito_icms
            |add:$valor_st
            |round:2
        }
      }
    }
  }

  response = {
    valor_difal : $valor_difal
    valor_st    : $valor_st
    credito_icms: $credito_icms
    perc_difal  : $perc_difal
    aliq_inter  : $aliq_inter
    aliq_interna: $estado_destino.aliquota_modal
    custo_fiscal: $custo_fiscal
    regime      : $regime
    uf_origem   : $input.uf_origem|to_upper
    uf_destino  : $input.uf_destino|to_upper
  }

  guid = "v2M1WGP75nSqKqBj_FAkQQ"
}