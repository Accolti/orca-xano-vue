// O DIFAL do MEI incide sobre o total da Nota Fiscal(Produto + IPI). então esse modulo vai calcular apenas: o valor_nota = Ex Produto = 300 Borda = 10 custo = 310 Area: 2m2 custo = 620 ipi=6%
// custo-nota= 620+6% = 620+37,2 = 657,2
function f_valor_custo_m2_Old {
  input {
    text nome_produto? filters=trim
    decimal comprimento?
    decimal largura?
    int quantidade?
  }

  stack {
    !function.run fBuscarProduto {
      input = {busca: $input.nome_produto}
    } as $prd
  
    !precondition (($prd|count) > 0) {
      error_type = "notfound"
      error = "Produto não encontrado"
      payload = "produto:"|concat:$input.nome_produto:""
    }
  
    !precondition (($prd.prds.Base_de_Calculo|first|to_upper) == "M2") {
      error_type = "notfound"
      error = "Esta função não aceita base diferente de M2"
      payload = "Base de Calculo"
        |concat:$prd.prds.Base_de_Calculo:""
    }
  
    function.run fc_m2_achar {
      input = {
        material_id: $prd.prds.material_id|first
        linha_id   : $prd.prds.linha_id|first
        borda_id   : $prd.prds.borda_id|first
      }
    } as $fc
  
    function.run f_retorna_fc {
      input = {
        comp: $input.comprimento
        larg: $input.largura
        fc  : $fc
      }
    } as $var_fc
  
    var $unidade_da_materia_prima {
      value = $prd.prds.Unidade|first|to_upper
    }
  
    var $base_de_calculo {
      value = $prd.prds.Base_de_Calculo|first|to_upper
    }
  
    var $cst_materia_prima {
      value = $prd.prds.valor|first
    }
  
    var $cst_borda {
      value = $prd.prds.borda_custo|first
    }
  
    var $aliquota_imp {
      value = $prd.prds.imp|first
    }
  
    var $aliquota_ipi {
      value = $prd.prds.ipi|first
    }
  
    var $ncm {
      value = $prd.prds.ncm|first
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
  
    var $materia_prima_mais_borda {
      value = $cst_materia_prima|add:$cst_borda
    }
  
    var $vlr_ipi {
      value = $materia_prima_mais_borda
        |multiply:$area_total_fc
        |multiply:$aliquota_ipi
        |divide:100
        |round:2
    }
  
    var $custo_nota {
      value = $materia_prima_mais_borda
        |multiply:$area_total_fc
        |add:$vlr_ipi
        |round:2
    }
  
    var $valores {
      value = {}
        |set:"custo_materia_prima":`$var.cst_materia_prima`
        |set:"custo_borda":$cst_borda
        |set:"custo_total":($materia_prima_mais_borda|multiply:$area_total_fc)
        |set:"[aliquota_ipi]":$aliquota_ipi
        |set:"valor_ipi":$vlr_ipi
        |set:"[custo_nota]":$custo_nota
    }
  
    !debug.stop {
      value = $vlr_ipi
    }
  }

  response = {
    descricao     : $input.nome_produto
    quantidade    : $input.quantidade
    largura       : $input.largura
    comprimento   : $input.comprimento
    largura_fc    : $largura_fc
    comprimento_fc: $comprimeto_fc
    ncm           : $ncm
    valores       : $valores
  }

  guid = "Sl1Dd7Xzg6EzeO0nitJ7EwgG6bA"
}