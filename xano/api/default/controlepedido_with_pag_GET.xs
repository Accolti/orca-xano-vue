// Query all ControlePedido records
query controlepedido_with_pag verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int page?
    int per_page?=50
    int offset?
  }

  stack {
    db.query ControlePedido {
      join = {
        Pedido : {
          table: "Pedido"
          where: $db.ControlePedido.pedido_id == $db.Pedido.id
        }
        Cliente: {
          table: "Cliente"
          where: $db.Pedido.cliente_id == $db.Cliente.id
        }
      }
    
      where = $db.ControlePedido.user_id == $auth.id
      sort = {ControlePedido.id: "asc"}
      eval = {
        cliente               : $db.Cliente.nome_fantasia
        valorTotalB2BB2C      : $db.Pedido.vlr_vnd_tot_b2b_b2c
        custoTotal            : $db.Pedido.vlr_cst_tot
        lucroTotal            : $db.Pedido.vlr_vnd_total|sub:$db.Pedido.vlr_cst_tot
        item                  : $db.ControlePedido.id
        freteB2BCobrado       : $db.Pedido.frtB2B
        freteB2CCobrado       : $db.Pedido.frtB2C
        vendaTotSemFrtSEfetivo: $db.Pedido.vlr_vnd_total
        lucroTotalReal        : $db.Pedido.vlr_cst_tot
        vendaTotalSFrete      : $db.Pedido.vlr_vnd_total
        qtdBoletos            : $db.ControlePedido.id
      }
    
      return = {
        type  : "list"
        paging: {
          page    : $input.page
          per_page: $input.per_page
          offset  : $input.offset
          metadata: false
        }
      }
    
      output = [
        "id"
        "created_at"
        "pedido_id"
        "codPedidoApp"
        "codPedidoVenda"
        "notaFiscal"
        "transportadoraB2B"
        "transportadoraB2C"
        "dataPrevisao"
        "dataChegada"
        "freteB2BReal"
        "freteB2CReal"
        "user_id"
        "cliente"
        "valorTotalB2BB2C"
        "custoTotal"
        "lucroTotal"
        "item"
        "freteB2BCobrado"
        "freteB2CCobrado"
        "vendaTotSemFrtSEfetivo"
        "lucroTotalReal"
        "vendaTotalSFrete"
        "qtdBoletos"
      ]
    } as $controlepedido
  
    var $cont {
      value = 0
    }
  
    var $TotalVendaGeral {
      value = 0
    }
  
    var $TotalCustoGeral {
      value = 0
    }
  
    var $TotalLucroGeral {
      value = 0
    }
  
    var $B2BResultado {
      value = 0
    }
  
    var $B2CResultado {
      value = 0
    }
  
    foreach ($controlepedido) {
      each as $ped {
        var.update $cont {
          value = $cont|add:1
        }
      
        var.update $ped.item {
          value = $cont
        }
      
        var.update $B2BResultado {
          value = $ped.freteB2BCobrado|subtract:$ped.freteB2BReal
        }
      
        var.update $B2CResultado {
          value = $ped.freteB2CCobrado|subtract:$ped.freteB2CReal
        }
      
        var.update $ped.vendaTotalSFrete {
          value = $ped.vendaTotSemFrtSEfetivo
        }
      
        // Este valor de venda é acrescido ou decrescido de alguma diferença de frete que tenha sido cobrado ou pago a mais ou a menos para calcular um lucro mais certo
        var.update $ped.vendaTotSemFrtSEfetivo {
          value = $ped.vendaTotSemFrtSEfetivo
            |add:($B2BResultado|add:$B2CResultado)
        }
      
        // Este valor de venda é acrescido ou decrescido de alguma diferença de frete que tenha sido cobrado ou pago a mais ou a menos para calcular um lucro mais certo
        var.update $ped.lucroTotalReal {
          value = $ped.vendaTotSemFrtSEfetivo|subtract:$ped.custoTotal
        }
      
        var.update $TotalVendaGeral {
          value = $TotalVendaGeral|add:$ped.vendaTotSemFrtSEfetivo
        }
      
        var.update $TotalCustoGeral {
          value = $TotalCustoGeral|add:$ped.custoTotal
        }
      
        var.update $TotalLucroGeral {
          value = $TotalLucroGeral|add:$ped.lucroTotalReal
        }
      
        function.run fQtdBoletosPorPedido {
          input = {pedido_id: $ped.pedido_id}
        } as $qtdPed
      
        var.update $ped.qtdBoletos {
          value = $qtdPed
        }
      }
    }
  }

  response = {
    result_1       : $controlepedido
    TotalVendaGeral: $TotalVendaGeral
    TotalCustoGeral: $TotalCustoGeral
    TotalLucroGeral: $TotalLucroGeral
  }

  guid = "WPmx6Tv-PfUhUNnmFx9PzPwfIfk"
}