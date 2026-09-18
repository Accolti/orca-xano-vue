query MercadoEnvio verb=POST {
  api_group = "Default"

  input {
  }

  stack {
    !debug.stop {
      value = $valores
    }
  
    !var $valores {
      value = {}
        |set:"from":({}|set:"postal_code":"18085350")
        |set:"to":({}|set:"postal_code":"18270070")
        |set:"products":([]
          |push:({}
            |set:"id":"x"
            |set:"width":11
            |set:"height":17
            |set:"length":11
            |set:"weight":0.3
            |set:"insurance_value":10.1
            |set:"quantity":1
          )
          |push:({}
            |set:"id":"y"
            |set:"width":16
            |set:"height":25
            |set:"length":11
            |set:"weight":0.3
            |set:"insurance_value":55.05
            |set:"quantity":2
          )
          |push:({}
            |set:"id":"z"
            |set:"width":22
            |set:"height":30
            |set:"length":11
            |set:"weight":1
            |set:"insurance_value":30
            |set:"quantity":1
          )
        )
    }
  
    var $params {
      value = {}
        |set:"from":({}|set:"postal_code":"18085350")
        |set:"to":({}|set:"postal_code":"18270070")
        |set:"products":([]
          |push:({}
            |set:"id":"x"
            |set:"width":11
            |set:"height":17
            |set:"length":11
            |set:"weight":0.3
            |set:"insurance_value":10.1
            |set:"quantity":1
          )
          |push:({}
            |set:"id":"y"
            |set:"width":16
            |set:"height":25
            |set:"length":11
            |set:"weight":0.3
            |set:"insurance_value":55.05
            |set:"quantity":2
          )
          |push:({}
            |set:"id":"z"
            |set:"width":22
            |set:"height":30
            |set:"length":11
            |set:"weight":1
            |set:"insurance_value":30
            |set:"quantity":1
          )
        )
    }
  
    !api.request {
      url = "https://www.melhorenvio.com.br/api/v2/me/shipment/calculate"
      method = "POST"
      params = ' {  "from": {     "postal_code": "18085350"   },   "to": {     "postal_code": "18270070"   },   "products": [     {       "id": "x",       "width": 11,       "height": 17,       "length": 11,       "weight": 0.3,       "insurance_value": 10.1,       "quantity": 1     },     {       "id": "y",       "width": 16,       "height": 25,       "length": 11,       "weight": 0.3,       "insurance_value": 55.05,       "quantity": 2     },     {       "id": "z",       "width": 22,       "height": 30,       "length": 11,       "weight": 1,       "insurance_value": 30,       "quantity": 1     }   ] }'
      headers = []
        |push:"Accept: application/json"
        |push:"Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIxIiwianRpIjoiYjY1YWFjOWU0NzRlYjc5N2JjNDZmMDA3MTQ0YWYzNjYxMDA2MGQ4MzAwNmIzYTVhZGE0ODI0OGJlMjNhYzdkM2VkZjIwZjQ3ZDU1ZGQyZmEiLCJpYXQiOjE3MDI5MTU5MDYuNDQyODQzLCJuYmYiOjE3MDI5MTU5MDYuNDQyODQ2LCJleHAiOjE3MzQ1MzgzMDYuNDEyMDIxLCJzdWIiOiI5YWUxMTUxYy1kYWJmLTRlYTMtOTQ3NC00MjZlOTlhNTAzZTAiLCJzY29wZXMiOlsic2hpcHBpbmctY2FsY3VsYXRlIl19.rmAa-HGbwBIx4u35so6hT9mySISEAcr9msesHiWLcNBvz8BrTB-009LGDXdKCuTR0cO0mMkLGPic5wEYLalmAnxCDLd7R3jkPyk3bmiE3Op3iGqjAho2U6CT12GB9n8E5yyxBqE9geSutTgrSpLZaFioJ4KrOnVhzLLG7-9c56y9kEuoHIcOge40bdHey10D5VdyU1Qw5p-ujgWc8b2ATql5Xp1CwMSp56-Xuh7SOpuWOxSTMS2x5rvQ7nLoqStjCTAPZlBsX_xbJnyI6j3f9IMAgYZZ0HpcJ3Ai1NfK9Jl8TiO_ZuAuSnVwsg3Yr0sFz6TmevPoX4TeFYmlYHjnqx7nPsGPg1vaR7qRxkLfE7BjIrFaOZH_tiEeHAJorE2Xv0c_veHcyFs2XMl0UwqSwpnMuBsgKfsq9IyejF8D0jCsgQb28ULPaWmGt6iJbB6S6WmneOKMpYIvOmY-OEqDOFSAClsin4HtD9255vc_qCZMHIenwif0N84tMZOqlhYfJmbhXWbyyP2CKLLWUX9q-l682szt6XvS14u_aehij5PNmVnXRrEkJHZrWYe1gdGX_HvL3ngwQ6iLWBjl2hPrJFwiy9r0pmq9MS5nI5YjxdeOWRKZyd1MoZ9ErPSMIW7ixw-yOkWwp56zLiBPNKsgwn10bc6gXEk6pqim16LCeMs"
        |push:"Content-Type: application/json"
        |push:"Content-Type: application/json"
        |push:"User-Agent: Aplicação contato@ecolti.com.br"
    } as $api_1
  
    api.request {
      url = "https://www.melhorenvio.com.br/api/v2/me/shipment/calculate"
      method = "POST"
      params = $params
      headers = []
        |push:"Accept: application/json"
        |push:("Authorization:"|concat:$env.key_MercadoEnvio:" ")
        |push:"Content-Type: application/json"
        |push:"User-Agent: Aplicação contato@ecolti.com.br"
    } as $api_1
  }

  response = $api_1
  guid = "QS5Wq-qAqf3C9OK-pbw935qDapE"
}