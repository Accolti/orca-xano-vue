// busca o fator de corte nas tabelas fator de corte
// REBIND-CHAIN: importar junto com os callers para re-resolver function.run
function fc_m2_achar {
  input {
    int material_id? {
      table = "Forma_Pagamento"
    }
  
    int linha_id? {
      table = "Tipo"
    }
  
    int borda_id? {
      table = "Borda"
    }
  }

  stack {
    db.query Tipo_Fator {
      join = {
        FC: {
          table: "Fator_de_Corte"
          where: $db.Tipo_Fator.fator_de_corte_id == $db.FC.id
        }
      }
    
      where = $db.Tipo_Fator.material_id == $input.material_id && $db.Tipo_Fator.linha_id == $input.linha_id && $db.Tipo_Fator.borda_id == $input.borda_id
      eval = {
        FC            : $db.FC.valor
        fator_corte_id: $db.FC.id
        tipo_fator_id : $db.Tipo_Fator.id
        modo_corte    : $db.FC.modo_corte
        comp_corte    : $db.FC.comp_corte
      }
    
      return = {type: "list"}
      output = [
        "id"
        "fator_de_corte_id"
        "material_id"
        "linha_id"
        "borda_id"
        "created_at"
        "FC"
        "fator_corte_id"
        "tipo_fator_id"
        "modo_corte"
        "comp_corte"
      ]
    } as $Tipo_Fator1
  }

  response = {!fc: $Tipo_Fator1.FC, tipo: $Tipo_Fator1}
  guid = "yzFAAJVun2hoYKlQRQZxZlqXRwI"
}