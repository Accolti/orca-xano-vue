function fBoleto_Pago {
  input {
    int user_id? {
      table = "User"
    }
  
    // Tipo  = "Count" - conta os vencidos
    // Tipo = "Dados" - Traz os boletos Vencidos
    text Tipo? filters=trim
  
    int boleto_id? {
      table = "Boleto"
    }
  }

  stack {
    conditional {
      if (($input.Tipo|to_upper) == "DADOS") {
        db.query Boleto {
          where = $db.Boleto.user_id == $input.user_id && $db.Boleto.pagamento != null && $db.Boleto.id ==? $input.boleto_id
          return = {type: "list"}
        } as $Boleto_1
      }
    
      else {
        db.query Boleto {
          where = $db.Boleto.user_id == $input.user_id && $db.Boleto.pagamento != null && $db.Boleto.id ==? $input.boleto_id
          return = {type: "count"}
        } as $Boleto_1
      }
    }
  }

  response = $Boleto_1
  guid = "dAjs4-m4z2aWYbKOdw1uK0jUeyk"
}