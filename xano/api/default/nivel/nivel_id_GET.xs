// Get nivel record
query "nivel/{nivel_id}" verb=GET {
  api_group = "Default"

  input {
    int nivel_id? filters=min:1
  }

  stack {
    db.get Nivel {
      field_name = "id"
      field_value = $input.nivel_id
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
  
    precondition ($nivel != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $nivel
  guid = "KsAgQlmvcaaCDh9RwxrNB-GjfZA"
}