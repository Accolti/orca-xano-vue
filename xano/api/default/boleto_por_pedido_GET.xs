// Query all Boleto records
query boleto_por_pedido verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int pedido_id? {
      table = "Pedido"
    }
  }

  stack {
    db.query Boleto {
      where = $db.Boleto.user_id == $auth.id && $db.Boleto.pedido_id == $input.pedido_id
      sort = {boleto.vencimento: "asc"}
      eval = {status: $db.boleto.id}
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "vencimento"
        "pagamento"
        "valor"
        "obs"
        "pedido_id"
        "user_id"
        "status"
      ]
    
      addon = [
        {
          name : "Pedido"
          input: {Pedido_id: $output.pedido_id}
          addon: [
            {
              name : "Cliente"
              input: {Cliente_id: $output.cliente_id}
              as   : "_cliente"
            }
          ]
          as   : "_pedido"
        }
      ]
    } as $boleto
  
    foreach ($boleto) {
      each as $item {
        function.run fBoleto_A_Vencer {
          input = {
            user_id  : $item.user_id
            Tipo     : '"contar"'
            qtdDias  : 5
            boleto_id: $item.id
          }
        } as $func_1
      
        !debug.stop {
          value = $func_1
        }
      
        conditional {
          if ($func_1 == 1) {
            var.update $item.status {
              value = "A VENCER"
            }
          }
        }
      
        function.run fBoleto_Vencido {
          input = {
            user_id  : $item.user_id
            Tipo     : '"contar"'
            boleto_id: $item.id
          }
        } as $func_2
      
        conditional {
          if ($func_2 == 1) {
            var.update $item.status {
              value = "VENCIDO"
            }
          }
        }
      
        !debug.stop {
          value = $func_2
        }
      
        function.run fBoleto_Pago {
          input = {
            user_id  : $item.user_id
            Tipo     : '"contar"'
            boleto_id: $item.id
          }
        } as $func_3
      
        conditional {
          if ($func_3 == 1) {
            var.update $item.status {
              value = "PAGO"
            }
          }
        }
      }
    }
  }

  response = $boleto
  guid = "ozinV70FDe7lXFh_I_jCMQX0mhY"
}