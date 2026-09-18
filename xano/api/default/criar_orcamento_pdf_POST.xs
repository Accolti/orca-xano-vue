query CriarOrcamentoPdf verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    function.run "External API PDF" {
      input = {orca_id: $input.orca_id}
    } as $api_1
  
    !debug.stop {
      value = $api_1
    }
  
    !db.add_or_edit Gerados {
      field_name = "id"
      field_value = $api_1.Gerados_1.id
      enforce_hidden_fields = false
      data = {
        orca_id: $api_1.Gerados_1.orca_id
        nome   : $api_1.request.params.output_file
        url    : $api_1.response.result.file
        tipo   : "pdf"
        imagem : ""
      }
    } as $Gerados_1
  
    // Fixo Para Testes
    !db.add_or_edit Gerados {
      field_name = "id"
      field_value = 26
      enforce_hidden_fields = false
      data = {
        orca_id: 102
        nome   : "ORC10257v26.pdf"
        url    : "https://craftmypdf-gen.s3.ap-southeast-1.amazonaws.com/7b1f1dda-d9b7-41e0-a863-5e58b5ee6001/ORC10257v26.pdf?AWSAccessKeyId=AKIA6ENCBKJYLWJUD36X&Expires=1699300667&Signature=5gAHOFVo2jmXRmmj8LQ8hKaM%2FOg%3D&X-Amzn-Trace-Id=Root%3D1-65400ab9-09141a451b580a430c278318%3BParent%3D29e1aeaec38f7b80%3BSampled%3D1%3BLineage%3Dc5de222e%3A0"
        imagem : ""
      }
    } as $Gerados_1
  }

  response = $api_1.Gerados_1
  guid = "APKAA6KAfnX-eI-t2ogt5IdV-Bg"
}