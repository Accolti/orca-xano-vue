table Tipo_Fator {
  auth = false

  schema {
    int id
    int fator_de_corte_id? {
      table = "Fator_de_Corte"
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
  
    timestamp created_at?=now {
      visibility = "private"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {
      type : "btree|unique"
      field: [
        {name: "fator_de_corte_id", op: "asc"}
        {name: "material_id", op: "asc"}
        {name: "linha_id", op: "asc"}
        {name: "borda_id", op: "asc"}
      ]
    }
  ]

  guid = "vcF2b56gI04wJl2ehAhqzPWbnVc"
}