function fBoleto_Vencido {
  input {
    int user_id? {
      table = "User"
    }
  
    // Tipo  = "Count" - conta os vencidos
    // Tipo = "Dados" - Traz os boletos Vencidos
    text Tipo? filters=trim
  
    // Se não for informado vai trazer uma lista.
    int boleto_id? {
      table = "Boleto"
    }
  }

  stack {
    var $dataHoje {
      value = "today"|to_timestamp:"UTC"
    }
  
    conditional {
      if (($input.Tipo|to_upper) == "DADOS") {
        db.query Boleto {
          where = $db.Boleto.user_id == $input.user_id && ($db.Boleto.vencimento < $dataHoje && $db.Boleto.pagamento == null && $db.Boleto.id ==? $input.boleto_id)
          return = {type: "list"}
        } as $Boleto_1
      }
    
      else {
        db.query Boleto {
          where = $db.Boleto.user_id == $input.user_id && ($db.Boleto.vencimento < $dataHoje && $db.Boleto.pagamento == null && $db.Boleto.id ==? $input.boleto_id)
          return = {type: "count"}
        } as $Boleto_1
      }
    }
  }

  response = $Boleto_1
  guid = "ZEX5reJohar8XE1CytEM5yz8e5I"
}