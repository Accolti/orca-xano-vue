query CalculoValorVenda_IDs verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    decimal comp
    decimal larg
    text nmMaterial? filters=trim
    text nmClassificacao? filters=trim
    text nmTipo? filters=trim
    text nmLinha? filters=trim
    text nmNivel? filters=trim
    text nmBorda? filters=trim
    decimal margem?
    decimal frete_b2b?
    int quantidade?=1
    decimal IPI?
    decimal IMP?
    bool bSimulaMargens?
  }

  stack {
    !function.run "" {
      input = {
        comp           : $input.comp
        larg           : $input.larg
        nmMaterial     : $input.nmMaterial
        nmClassificacao: $input.nmClassificacao
        nmTipo         : $input.nmTipo
        nmLinha        : $input.nmLinha
        nmNivel        : $input.nmNivel
        nmBorda        : $input.nmBorda
        margem         : $input.margem
        frete_b2b      : $input.frete_b2b
        quantidade     : $input.quantidade
        IPI            : $input.IPI
        IMP            : $input.IMP
      }
    } as $func_1
  
    function.run f_CalculoValorVenda_IDs {
      input = {
        comp           : $input.comp
        larg           : $input.larg
        nmMaterial     : $input.nmMaterial
        nmClassificacao: $input.nmClassificacao
        nmTipo         : $input.nmTipo
        nmLinha        : $input.nmLinha
        nmNivel        : $input.nmNivel
        nmBorda        : $input.nmBorda
        margem         : $input.margem
        frete_b2b      : $input.frete_b2b
        quantidade     : $input.quantidade
        IPI            : $input.IPI
        IMP            : $input.IMP
        bSimulaMargens : $input.bSimulaMargens
      }
    } as $func_1
  }

  response = $func_1
  guid = "Il86PU_j8ElneAimtWYnaZQy_tQ"
}