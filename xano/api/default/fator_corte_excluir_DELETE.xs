// Exclui um Fator_de_Corte (dev tool, auth User).
// Bloqueia se estiver em uso (referenciado em Tipo_Fator ou em Produto.fator_de_corte_id)
// para não quebrar o cálculo.
query fator_corte_excluir verb=DELETE {
  api_group = "Default"
  auth = "User"

  input {
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  }

  stack {
    precondition ($input.fator_de_corte_id != null) {
      error_type = "badrequest"
      error = "Informe o fator_de_corte_id."
    }
  
    // Referenciado em Tipo_Fator?
    db.query Tipo_Fator {
      where = $db.Tipo_Fator.fator_de_corte_id == $input.fator_de_corte_id
      return = {type: "count"}
    } as $qtd_tipo_fator
  
    // Referenciado em Produto (fator fixo)?
    db.query Produto {
      where = $db.Produto.fator_de_corte_id == $input.fator_de_corte_id
      return = {type: "count"}
    } as $qtd_produto
  
    precondition ($qtd_tipo_fator == 0 && $qtd_produto == 0) {
      error_type = "badrequest"
      error = "Fator de corte em uso (associação Tipo_Fator ou produto fixo). Não é possível excluir."
    }
  
    db.del Fator_de_Corte {
      field_name = "id"
      field_value = $input.fator_de_corte_id
    }
  }

  response = null
  guid = "OrcaKap-fator-corte-excluir"
}