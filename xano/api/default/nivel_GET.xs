// Query all nivel records
query nivel verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Nivel {
      return = {type: "list"}
      addon = [
        {
          name  : "Material"
          output: ["id", "nome"]
          input : {Material_id: $output.material_id}
          as    : "_material"
        }
        {
          name  : "Linha"
          output: ["id", "nome"]
          input : {Linha_id: $output.linha_id}
          as    : "_linha"
        }
        {
          name  : "Tipo"
          output: ["id", "nome"]
          input : {Tipo_id: $output.tipo_id}
          as    : "_tipo"
        }
      ]
    } as $nivel
  }

  response = $nivel
  guid = "NRVzcqufqNPSBzUdllpSVbvoDyg"
}