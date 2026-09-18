// Calcula a quantidade de kits necessários para cobrir uma determinada área. Entrar com a área que o cliente quer cobrir, as dimensões do produto e quantas peças compõe o kit
function Calc_QtdKits {
  input {
    decimal Area_Cliente?
    decimal Larg_Kit?
    decimal Comp_Kit?
    int Qtd_de_Pecas_Kit?
  }

  stack {
    // Area coberta pelo kit.  (m2 ou cm2 ou km2...)
    var $Area_Kit {
      value = $input.Larg_Kit
        |multiply:$input.Comp_Kit
        |multiply:$input.Qtd_de_Pecas_Kit
    }
  
    // Qtd de kits  necessária para cobrir a área do cliente
    var $Qtd_Kits {
      value = $input.Area_Cliente|divide:$Area_Kit|ceil
    }
  
    // Area total coberta pelo numero de kits fornecidos
    var $Area_Coberta_Kit {
      value = $Area_Kit|multiply:$Qtd_Kits|round:2
    }
  
    var $total_Pecas {
      value = $Qtd_Kits|multiply:$input.Qtd_de_Pecas_Kit
    }
  }

  response = {
    Qtd_Kits              : $Qtd_Kits
    Area_Kit              : $Area_Kit
    Area_Total_Coberta_Kit: $Area_Coberta_Kit
    Total_Pecas           : $total_Pecas
  }

  guid = "1vDPYBs76kE-0w3Lgs3avTUWX7Q"
}