// Cadastro de Fator_de_Corte (dev tool, auth User).
// Cria (sem id) ou edita (com id) um fator de corte, incluindo o modo (lista/passo).
query fator_corte_cadastrar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  
    text nome? filters=trim
    decimal[] valor?
  
    // Largura base (m)
    decimal larg_base?
  
    // Passo de corte (m) — usado quando modo_corte = "passo" (ex.: 0.5)
    decimal comp_corte?
  
    // Tamanho total do rolo (m)
    decimal tam_total?
  
    enum modo_corte?=lista {
      values = ["lista", "passo"]
    }
  
    text obs? filters=trim
  }

  stack {
    var $salvo {
      value = null
    }
  
    conditional {
      if ($input.fator_de_corte_id != null) {
        db.edit Fator_de_Corte {
          field_name = "id"
          field_value = $input.fator_de_corte_id
          enforce_hidden_fields = false
          data = {
            nome      : $input.nome
            valor     : $input.valor
            larg_base : $input.larg_base
            comp_corte: $input.comp_corte
            tam_total : $input.tam_total
            modo_corte: $input.modo_corte
            obs       : $input.obs
          }
        } as $salvo
      }
    
      else {
        db.add Fator_de_Corte {
          enforce_hidden_fields = false
          data = {
            nome      : $input.nome
            valor     : $input.valor
            larg_base : $input.larg_base
            comp_corte: $input.comp_corte
            tam_total : $input.tam_total
            modo_corte: $input.modo_corte
            obs       : $input.obs
            created_at: "now"
          }
        } as $salvo
      }
    }
  }

  response = {fator_de_corte_id: $salvo.id, fator: $salvo}
  guid = "OrcaKap-fator-corte-cadastrar"
}