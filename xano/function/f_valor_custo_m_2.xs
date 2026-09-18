// O DIFAL do MEI incide sobre o total da Nota Fiscal(Produto + IPI). então esse modulo vai calcular apenas: o valor_nota = Ex Produto = 300 Borda = 10 custo = 310 Area: 2m2 custo = 620 ipi=6%
// custo-nota= 620+6% = 620+37,2 = 657,2
// REBIND-fix: recompilação para re-resolver function.run (fc_m2_achar / f_retorna_fc / f_transformaArrayemString)
function f_valor_custo_m2 {
  input {
    decimal comprimento?
    decimal largura?
    decimal quantidade?
    json[] prd?
  
    // Vendedor marcou medida exata → aplica porcentagem_acrescimo do produto no custo
    bool com_medida_exata?
  }

  stack {
    var $produto {
      value = $input.prd
    }
  
    precondition (($produto|count) > 0) {
      error_type = "notfound"
      error = "Produto não encontrado"
      payload = "produto:"|concat:$input.nome_produto:""
    }
  
    var.update $produto {
      value = $produto|first
    }
  
    precondition (($produto.Base_de_Calculo|to_upper) == "M2") {
      error_type = "notfound"
      error = "Esta função não aceita base diferente de M2"
      payload = "Base de Calculo"
        |concat:$input.prd.Base_de_Calculo:""
    }
  
    // Resolução do fator de corte (Opção X):
    // 1º Produto.fator_de_corte_id (fixo no produto, ex.: M2 passo 0.5)
    // 2º Tipo_Fator (material+linha+borda)
    // 3º sem fator (dimensões originais)
    var $fator_corte {
      value = []
    }
  
    var $fator_de_corte_id {
      value = 0
    }
  
    var $tipo_fator_id {
      value = 0
    }
  
    var $modo_corte {
      value = "lista"
    }
  
    var $passo_corte {
      value = 0
    }
  
    conditional {
      if ($produto.fator_de_corte_id != null && $produto.fator_de_corte_id > 0) {
        db.get Fator_de_Corte {
          field_name = "id"
          field_value = $produto.fator_de_corte_id
        } as $fc_direto
      
        var.update $fator_de_corte_id {
          value = $fc_direto.id
        }
      
        var.update $fator_corte {
          value = $fc_direto.valor
        }
      
        var.update $modo_corte {
          value = $fc_direto.modo_corte
        }
      
        var.update $passo_corte {
          value = $fc_direto.comp_corte
        }
      }
    
      else {
        function.run fc_m2_achar {
          input = {
            material_id: $produto.material_id
            linha_id   : $produto.linha_id
            borda_id   : $produto.borda_id
          }
        } as $fc
      
        var.update $fator_corte {
          value = $fc.tipo.FC
        }
      
        var.update $fator_de_corte_id {
          value = $fc.tipo.fator_de_corte_id|first
        }
      
        var.update $tipo_fator_id {
          value = $fc.tipo.tipo_fator_id|first
        }
      
        var.update $modo_corte {
          value = $fc.tipo.modo_corte|first|first_notnull:"lista"
        }
      
        var.update $passo_corte {
          value = $fc.tipo.comp_corte|first|first_notnull:0
        }
      }
    }
  
    function.run f_retorna_fc {
      input = {
        comp      : $input.comprimento
        larg      : $input.largura
        fc        : $fator_corte
        modo_corte: $modo_corte
        passo     : $passo_corte
      }
    } as $var_fc
  
    var $unidade_da_materia_prima {
      value = $produto.Unidade|to_upper
    }
  
    var $base_de_calculo {
      value = $produto.Base_de_Calculo|to_upper
    }
  
    var $cst_materia_prima {
      value = $produto.valor
    }
  
    var $cst_borda {
      value = $produto.borda_valor
    }
  
    !var $aliquota_imp {
      value = $produto.imp
    }
  
    var $aliquota_ipi {
      value = $produto.ipi
    }
  
    var $descricao {
      value = []
        |push:$produto.material_nome
        |push:$produto.linha_nome
        |push:$produto.tipo_nome
        |push:$produto.nivel_nome
        |push:$produto.borda_nome
    }
  
    function.run f_transformaArrayemString {
      input = {Array: $descricao}
    } as $descricao
  
    var $ncm {
      value = $produto.ncm
    }
  
    var $comprimeto_fc {
      value = $var_fc.new_comp
    }
  
    var $largura_fc {
      value = $var_fc.new_larg
    }
  
    var $area_total_fc {
      value = $comprimeto_fc
        |multiply:$largura_fc
        |multiply:$input.quantidade
    }
  
    var $materia_prima_mais_borda_total {
      value = $cst_materia_prima|add:$cst_borda
    }
  
    // Medida exata (marcada pelo vendedor): aplica porcentagem_acrescimo do produto no custo de fábrica.
    var $acrescimo_medida_exata {
      value = 0
    }
  
    conditional {
      if ($input.com_medida_exata && $produto.com_medida_exata) {
        var.update $materia_prima_mais_borda_total {
          value = $materia_prima_mais_borda_total
            |multiply:(1
              |add:($produto.porcentagem_acrescimo|divide:100)
            )
        }
      
        var.update $acrescimo_medida_exata {
          value = $produto.porcentagem_acrescimo
        }
      }
    }
  
    var $vlr_ipi_total {
      value = $materia_prima_mais_borda_total
        |multiply:$area_total_fc
        |multiply:$aliquota_ipi
        |divide:100
        |round:2
    }
  
    var $custo_nota_total {
      value = $materia_prima_mais_borda_total
        |multiply:$area_total_fc
        |add:$vlr_ipi_total
        |round:2
    }
  
    var $valores {
      value = {}
        |set:"custo_materia_prima":`$var.cst_materia_prima`
        |set:"custo_borda":$cst_borda
        |set:"custo_total":($materia_prima_mais_borda_total|multiply:$area_total_fc)
        |set:"[aliquota_ipi]":$aliquota_ipi
        |set:"valor_ipi_tot":$vlr_ipi_total
        |set:"valor_ipi_unit":($vlr_ipi_total|divide:$input.quantidade)
        |set:"[custo_nota_tot]":$custo_nota_total
        |set:"[custo_nota_unit]":($custo_nota_total|divide:$input.quantidade)
    }
  }

  response = {
    descricao             : $descricao
    quantidade            : $input.quantidade
    largura               : $input.largura
    comprimento           : $input.comprimento
    largura_fc            : $largura_fc
    comprimento_fc        : $comprimeto_fc
    ncm                   : $ncm
    fc                    : $fator_corte
    fator_de_corte_id     : $fator_de_corte_id
    tipo_fator_id         : $tipo_fator_id
    modo_corte            : $modo_corte
    passo_corte           : $passo_corte
    com_medida_exata      : ($input.com_medida_exata == true) && ($produto.com_medida_exata == true)
    acrescimo_medida_exata: $acrescimo_medida_exata
    detalhes_calculo      : null
    valores               : $valores
  }

  guid = "o87loq220YRgP6_crKNX3eNKu78"
}