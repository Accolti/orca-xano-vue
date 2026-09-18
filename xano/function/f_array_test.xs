function fArray_Test {
  input {
    int[] array1?
  }

  stack {
    var $array2 {
      value = []
        |push:7
        |push:2
        |push:6
        |push:9
    }
  
    var $usuarios {
      value = []
        |push:({}
          |set:"nome":"João"
          |set:"idade":76
        )
        |push:({}
          |set:"nome":"Pedro"
          |set:"idade":43
        )
        |push:({}
          |set:"nome":"Maria"
          |set:"idade":36
        )
    }
  
    var $mercadoEnvio {
      value = {}
        |set:"from":({}|set:"postal_code":"96020360")
        |set:"to":({}|set:"postal_code":"01018020")
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
  
    var $resultado {
      value = $mercadoEnvio
    }
  }

  response = $resultado
  guid = "OvCXjzyhHBn5eH9gYlsGZCQpYtY"
}