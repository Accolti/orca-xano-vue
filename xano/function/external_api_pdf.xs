function "External API PDF" {
  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    function.run Orcamento_Detalhes_Function {
      input = {
        orca_codigo: ""
        newMargem  : ""
        orca_id    : $input.orca_id
      }
    } as $detalheOrca
  
    db.query Gerados {
      where = $db.Gerados.orca_id == $input.orca_id
      return = {type: "count"}
    } as $Contador
  
    var $nome_arquivo {
      value = $detalheOrca.ORCA_1.cod_orca
        |concat:("v"|concat:($Contador|add:1):""):""
        |concat:".pdf":""
    }
  
    !debug.stop {
      value = $detalheOrca
    }
  
    !var.update $nome_arquivo {
      value = $nome_arquivo
        |replace:"$":($Gerados_1.id|concat:".pdf":"")
    }
  
    api.request {
      url = "https://api.craftmypdf.com/v1/create"
      method = "POST"
      params = {}
        |set:"template_id":$env.template_Orcamento_Id
        |set:"export_type":"json"
        |set:"expiration":10080
        |set:"output_file":$nome_arquivo
        |set:"data":$detalheOrca
      headers = []
        |push:"Content-Type: application/json"
        |push:("X-API-KEY:"|concat:$env.key_craftmypdf:" ")
      verify_host = false
      verify_peer = false
    } as $api_1
  
    !debug.stop {
      value = $api_1
    }
  
    // Inserir Gerado
    db.add_or_edit Gerados {
      field_name = "id"
      field_value = 0
      enforce_hidden_fields = false
      data = {
        orca_id: $input.orca_id
        nome   : $nome_arquivo
        url    : $api_1.response.result.file
        tipo   : "pdf"
      }
    } as $Gerados_1
  }

  response = {result_1: $api_1, Gerados_1: $Gerados_1}
  tags = ["orcamento", "pdf"]
  guid = "pVuFxzCZzsZKoswRW97KMC4m-6g"
}