// Cadastro de associação Tipo_Fator (dev tool, auth User).
// Liga material+linha+borda → fator_de_corte_id (usado no M2 como fallback quando o
// produto não tem fator fixo). Cria (sem id) ou edita (com id). Se excluir=true, remove.
query tipo_fator_cadastrar verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int tipo_fator_id? {
      table = "Tipo_Fator"
    }
  
    int material_id? {
      table = "Material"
    }
  
    int linha_id? {
      table = "Linha"
    }
  
    int borda_id? {
      table = "Borda"
    }
  
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
    }
  
    bool excluir?
  }

  stack {
    // Remoção
    conditional {
      if ($input.excluir && $input.tipo_fator_id != null) {
        db.del Tipo_Fator {
          field_name = "id"
          field_value = $input.tipo_fator_id
        }
      }
    
      else {
        // Cria ou edita
        conditional {
          if ($input.tipo_fator_id != null) {
            db.edit Tipo_Fator {
              field_name = "id"
              field_value = $input.tipo_fator_id
              enforce_hidden_fields = false
              data = {
                material_id      : $input.material_id
                linha_id         : $input.linha_id
                borda_id         : $input.borda_id
                fator_de_corte_id: $input.fator_de_corte_id
              }
            } as $salvo
          }
        
          else {
            db.add Tipo_Fator {
              enforce_hidden_fields = false
              data = {
                material_id      : $input.material_id
                linha_id         : $input.linha_id
                borda_id         : $input.borda_id
                fator_de_corte_id: $input.fator_de_corte_id
                created_at       : "now"
              }
            } as $salvo
          }
        }
      }
    }
  }

  response = {tipo_fator_id: $salvo.id, "associação": $salvo}
  guid = "OrcaKap-tipo-fator-cadastrar"
}