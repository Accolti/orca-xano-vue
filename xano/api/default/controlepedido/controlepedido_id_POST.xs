// UPDATE NA TABELA
query "controlepedido/{controlepedido_id}" verb=POST {
  api_group = "Default"

  input {
    int controlepedido_id? filters=min:1
    dblink {
      table = "ControlePedido"
    }
  }

  stack {
    db.get ControlePedido {
      field_name = "id"
      field_value = $input.controlepedido_id
    } as $pedido
  
    !debug.stop {
      value = $pedido
    }
  
    db.edit ControlePedido {
      field_name = "id"
      field_value = $input.controlepedido_id
      enforce_hidden_fields = false
      data = {
        codPedidoApp     : $input.codPedidoApp|first_notnull:$pedido.codPedidoApp
        codPedidoVenda   : $input.codPedidoVenda|first_notnull:$pedido.codPedidoVenda
        notaFiscal       : $input.notaFiscal|first_notnull:$pedido.notaFiscal
        transportadoraB2B: $input.transportadoraB2B|first_notnull:$pedido.transportadoraB2B
        transportadoraB2C: $input.transportadoraB2C|first_notnull:$pedido.transportadoraB2C
        dataPrevisao     : $input.dataPrevisao
        dataChegada      : $input.dataChegada
        freteB2BReal     : $input.freteB2BReal
        freteB2CReal     : $input.freteB2CReal
      }
    } as $model
  }

  response = $model
  guid = "SR9UiEREAOrzVlNNYLJ4_mzfamE"
}