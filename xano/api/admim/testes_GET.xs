query Testes verb=GET {
  api_group = "Admim"

  input {
  }

  stack {
    var $myArray {
      value = []
        |push:0.1
        |push:0.5
        |push:0.9
        |push:1.85
    }
  
    var $var_1 {
      value = $myArray
    }
  
    var $var_2 {
      value = 0
    }
  
    var $var_3 {
      value = 1000
    }
  
    var $dec_Valor {
      value = 5.697
    }
  
    var $dec_Custo {
      value = 128.5
    }
  
    var $dec_Venda {
      value = 224.875
    }
  
    var $dec_Lucro {
      value = 0
    }
  
    var $dec_Margem {
      value = 0
    }
  
    var $Margem {
      value = 0
    }
  
    foreach ($myArray) {
      each as $item {
        var.update $var_2 {
          value = $item|multiply:$var_3
        }
      
        conditional {
          if (($var_2|divide:2) >= 100) {
            var.update $var_2 {
              value = 1000
                |add:45
                |multiply:$var_2
                |add:$dec_Valor
            }
          }
        }
      }
    }
  
    var.update $dec_Lucro {
      value = $dec_Venda|subtract:$dec_Custo
    }
  
    var.update $Margem {
      value = $dec_Lucro|add:$dec_Custo
    }
  
    var.update $Margem {
      value = $Margem
        |divide:$dec_Custo
        |subtract:1
        |multiply:100
    }
  
    !var.update $Margem {
      value = $Margem|subtract:1|multiply:100
    }
  }

  response = {
    result_1: $var_2
    Lucro   : $dec_Lucro
    Venda   : $dec_Venda
    Custo   : $dec_Custo
    Margem  : $Margem
  }

  guid = "omv2AgVDT2YvpC2IBmpO7qua2ZE"
}