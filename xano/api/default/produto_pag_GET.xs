// Query all produto records
query produto_pag verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int page?
    int perPage?
    int offset?
  }

  stack {
    db.query Produto {
      override_sort = "sort"
      return = {
        type  : "list"
        paging: {
          page    : $input.page
          per_page: $input.perPage
          totals  : true
          offset  : $input.offset
        }
      }
    
      addon = [
        {
          name : "Material"
          input: {Material_id: $output.material_id}
          as   : "items._material"
        }
        {
          name : "Linha"
          input: {Linha_id: $output.linha_id}
          as   : "items._linha"
        }
        {
          name : "Tipo"
          input: {Tipo_id: $output.tipo_id}
          as   : "items._tipo"
        }
        {
          name : "Nivel"
          input: {Nivel_id: $output.nivel_id}
          as   : "items._nivel"
        }
        {
          name : "Classificacao"
          input: {Classificacao_id: $output.classificacao_id}
          as   : "items._classificacao"
        }
      ]
    } as $produto
  }

  response = $produto
  guid = "rDbLPUmsx_8e80Rs4EtRtswtGis"
}