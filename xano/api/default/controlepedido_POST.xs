// INSERT  NA TABELA
query controlepedido verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    dblink {
      table = "ControlePedido"
    }
  }

  stack {
    db.add ControlePedido {
      enforce_hidden_fields = false
      data = {
        created_at       : "now"
        pedido_id        : $input.pedido_id
        codPedidoApp     : $input.codPedidoApp
        codPedidoVenda   : $input.codPedidoVenda
        notaFiscal       : $input.notaFiscal
        transportadoraB2B: $input.transportadoraB2B
        transportadoraB2C: $input.transportadoraB2C
        dataPrevisao     : $input.dataPrevisao
        dataChegada      : $input.dataChegada
        freteB2BCobrado  : $input.freteB2BCobrado
        user_id          : $input.user_id
      }
    } as $model
  }

  response = $model
  guid = "sZNuf5xNBlItoGnMh4Nb418Xq5Q"
}