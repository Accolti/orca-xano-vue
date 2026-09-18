// Lista os Fatores de Corte + associações Tipo_Fator (material+linha+borda) para a
// dev tool de fator de corte (auth User). Inclui os campos de modo (lista/passo).
query fatores_corte_dev verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Fator_de_Corte {
      sort = {id: "asc"}
      return = {type: "list"}
    } as $fatores
  
    db.query Tipo_Fator {
      join = {
        Material: {
          table: "Material"
          where: $db.Tipo_Fator.material_id == $db.Material.id
        }
        Linha   : {
          table: "Linha"
          type : "left"
          where: $db.Tipo_Fator.linha_id ==? $db.Linha.id
        }
        Borda   : {
          table: "Borda"
          type : "left"
          where: $db.Tipo_Fator.borda_id ==? $db.Borda.id
        }
      }
    
      sort = {id: "asc"}
      eval = {
        material_nome: $db.Material.nome
        linha_nome   : $db.Linha.nome
        borda_nome   : $db.Borda.nome
      }
    
      return = {type: "list"}
      output = [
        "id"
        "fator_de_corte_id"
        "material_id"
        "linha_id"
        "borda_id"
        "created_at"
        "material_nome"
        "linha_nome"
        "borda_nome"
      ]
    } as $associacoes
  }

  response = {fatores: $fatores, associacoes: $associacoes}
  guid = "OrcaKap-fatores-corte-dev"
}