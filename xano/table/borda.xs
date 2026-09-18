// Tipo de Bordas dos Tatepes
table Borda {
  auth = false

  schema {
    int id
    text nome? filters=trim
    text Obs? filters=trim
    int material_id? {
      table = "Material"
    }
  
    decimal valor?
    enum Unidade?=M2 {
      values = ["M2", "ML", ""]
    }
  
    timestamp created_at?=now {
      visibility = "private"
    }
  
    bool ativo?=true
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {
      type : "btree"
      field: [{name: "nome", op: "asc"}, {name: "material_id", op: "asc"}]
    }
    {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    {
      type : "btree|unique"
      field: [{name: "nome", op: "asc"}, {name: "material_id", op: "asc"}]
    }
  ]

  guid = "QFMKEUuyEA9YCdps5dBjSDDEzK8"
}