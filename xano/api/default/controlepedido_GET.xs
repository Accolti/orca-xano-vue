// Query all ControlePedido records
query controlepedido verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int page?
    int per_page?=3
    int offset?
    date? dt_ini?
    date? dt_fim?
  }

  stack {
    db.query ControlePedido {
      join = {
        Pedido          : {
          table: "Pedido"
          where: $db.ControlePedido.pedido_id == $db.Pedido.id
        }
        Cliente         : {
          table: "Cliente"
          where: $db.Pedido.cliente_id == $db.Cliente.id
        }
        Endereco_Cliente: {
          table: "Endereco_Cliente"
          where: $db.Endereco_Cliente.cliente_id == $db.Cliente.id
        }
      }
    
      where = $db.ControlePedido.user_id == $auth.id && ($db.ControlePedido.created_at|between:$input.dt_ini:$input.dt_fim) == true
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
        estado                : $db.Endereco_Cliente.estado
        cidade                : $db.Endereco_Cliente.cidade
      }
    
      return = {
        type  : "list"
        paging: {
          page    : $input.page
          per_page: $input.per_page
          totals  : true
          offset  : $input.offset
        }
      }
    
      output = [
        "itemsReceived"
        "curPage"
        "nextPage"
        "prevPage"
        "offset"
        "itemsTotal"
        "pageTotal"
        "items.id"
        "items.created_at"
        "items.pedido_id"
        "items.codPedidoApp"
        "items.codPedidoVenda"
        "items.notaFiscal"
        "items.transportadoraB2B"
        "items.transportadoraB2C"
        "items.dataPrevisao"
        "items.dataChegada"
        "items.freteB2BReal"
        "items.freteB2CReal"
        "items.user_id"
        "items.cliente"
        "items.valorTotalB2BB2C"
        "items.custoTotal"
        "items.lucroTotal"
        "items.item"
        "items.freteB2BCobrado"
        "items.freteB2CCobrado"
        "items.vendaTotSemFrtSEfetivo"
        "items.lucroTotalReal"
        "items.vendaTotalSFrete"
        "items.qtdBoletos"
        "items.estado"
        "items.cidade"
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
  
    !debug.stop {
      value = $controlepedido.items
    }
  
    foreach ($controlepedido.items) {
      each as $ped {
        var.update $cont {
          value = $cont|add:1
        }
      
        !debug.stop {
          value = $ped
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

  guid = "b4EmFqRsSj6aoswzEzqnAR51-qo"
}