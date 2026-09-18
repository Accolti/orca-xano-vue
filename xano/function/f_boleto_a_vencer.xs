function fBoleto_A_Vencer {
  input {
    int user_id? {
      table = "User"
    }
  
    // Tipo  = "Count" - conta os vencidos
    // Tipo = "Dados" - Traz os boletos Vencidos
    text Tipo? filters=trim
  
    // Quantidade de dias a acrescentar a data de hoje para achar o range de boletos  que estarão vencendo
    int qtdDias?
  
    int boleto_id? {
      table = "Boleto"
    }
  }

  stack {
    var $dataHoje {
      value = "today"|to_timestamp:"UTC"
    }
  
    var $DaysAAdicionar {
      value = "+"
        |concat:($input.qtdDias|subtract:1):""
        |concat:"days":" "
    }
  
    var $dataHojePlusDaysAAdicionar {
      value = $dataHoje
        |transform_timestamp:$DaysAAdicionar:"UTC"
    }
  
    conditional {
      if (($input.Tipo|to_upper) == "DADOS") {
        db.query Boleto {
          where = $db.Boleto.user_id == $input.user_id && (($db.Boleto.vencimento|between:$dataHoje:$dataHojePlusDaysAAdicionar) && $db.Boleto.pagamento == null && $db.Boleto.id ==? $input.boleto_id)
          return = {type: "list"}
        } as $Boleto_1
      }
    
      else {
        db.query Boleto {
          where = $db.Boleto.user_id == $input.user_id && (($db.Boleto.vencimento|between:$dataHoje:$dataHojePlusDaysAAdicionar) && $db.Boleto.pagamento == null && $db.Boleto.id ==? $input.boleto_id)
          return = {type: "count"}
        } as $Boleto_1
      }
    }
  }

  response = $Boleto_1
  guid = "8QEWtc5a9URT_6J7p5BXIwsWjrU"
}