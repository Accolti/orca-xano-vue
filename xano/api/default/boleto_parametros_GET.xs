// Query all Boleto records
query boleto_parametros verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text nome_cliente? filters=trim
    int qtdDias?=7
    enum? status_desc? {
      values = ["PAGO", "A VENCER", "EM DIA", "VENCIDO", "null"]
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
  
    // var $dataHojePlusDaysDate {
    //   value = $dataHojePlusDaysAAdicionar|to_date
    // }
  
    db.query Boleto {
      join = {
        Pedido : {
          table: "Pedido"
          where: $db.Boleto.pedido_id == $db.Pedido.id
        }
        Cliente: {
          table: "Cliente"
          where: $db.Pedido.cliente_id == $db.Cliente.id
        }
      }
    
      where = $db.Boleto.user_id == $auth.id && ($db.Cliente.nome_fantasia ilike? $input.nome_cliente) && (($input.status_desc == "PAGO" && $db.boleto.pagamento != null) || ($input.status_desc == "A VENCER" && $db.boleto.pagamento == null && ($db.boleto.vencimento|between:$dataHoje:$dataHojePlusDaysAAdicionar)) || ($input.status_desc == "EM DIA" && $db.boleto.pagamento == null && $db.boleto.vencimento > $dataHoje && !($db.boleto.vencimento|between:$dataHoje:$dataHojePlusDaysAAdicionar)) || ($input.status_desc == "VENCIDO" && $db.boleto.pagamento == null && $db.boleto.vencimento <= $dataHoje) || ($input.status_desc == null || $input.status_desc == "null"))
      sort = {boleto.vencimento: "asc"}
      eval = {
        status   : $db.boleto.id
        nmCliente: $db.Cliente.nome_fantasia
      }
    
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "vencimento"
        "pagamento"
        "valor"
        "forma_pagamento_id"
        "obs"
        "pedido_id"
        "user_id"
        "status"
        "nmCliente"
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
  
    var $x1 {
      value = ""
    }
  }

  response = $boleto
  guid = "vrUEGIvhBVqKu2X0srMF6ininYw"
}