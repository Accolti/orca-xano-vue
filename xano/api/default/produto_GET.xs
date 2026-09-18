// Query all produto records
query produto verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Produto {
      return = {type: "list"}
      addon = [
        {
          name : "Material"
          input: {Material_id: $output.material_id}
          as   : "_material"
        }
        {
          name : "Linha"
          input: {Linha_id: $output.linha_id}
          as   : "_linha"
        }
        {
          name : "Tipo"
          input: {Tipo_id: $output.tipo_id}
          as   : "_tipo"
        }
        {
          name : "Nivel"
          input: {Nivel_id: $output.nivel_id}
          as   : "_nivel"
        }
        {
          name : "Classificacao"
          input: {Classificacao_id: $output.classificacao_id}
          as   : "_classificacao"
        }
      ]
    } as $produto
  }

  response = $produto
  guid = "GVY3a8Vuv4dud2dtM4ZFypNRqTE"
}