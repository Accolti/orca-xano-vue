function fSumPedidosBoletos {
  input {
    date? dt_ini?
    date? dt_fin?
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.query Pedido {
      join = {
        ControlePedido: {
          table: "ControlePedido"
          where: $db.Pedido.id == $db.ControlePedido.pedido_id
        }
      }
    
      where = ($db.Pedido.created_at|between:$input.dt_ini:$input.dt_fin) == true && $db.Pedido.user_id == $input.user_id
      sort = {Pedido.id: "asc"}
      eval = {
        frtB2BReal: $db.ControlePedido.freteB2BReal
        frtB2CReal: $db.ControlePedido.freteB2CReal
      }
    
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "num_ped"
        "cod_orca"
        "cliente_id"
        "frtB2B"
        "frtB2C"
        "user_id"
        "margem"
        "desconto"
        "vlr_cst_tot"
        "vlr_cst_tot_ipi"
        "vlr_cst_tot_imp"
        "vlr_vnd_total"
        "vlr_vnd_tot_ipi"
        "vlr_vnd_tot_imp"
        "vlr_vnd_tot_b2b"
        "vlr_vnd_tot_b2b_b2c"
        "observacao"
        "frtB2BReal"
        "frtB2CReal"
      ]
    } as $Pedido1
  
    db.query Boleto {
      join = {
        Pedido: {
          table: "Pedido"
          where: $db.Boleto.pedido_id == $db.Pedido.id
        }
      }
    
      where = $db.Boleto.pedido_id in $Pedido1.id
      sort = {Pedido.id: "asc", Boleto.vencimento: "asc"}
      return = {type: "list"}
    } as $Boleto1
  }

  response = {
    !Pedido_Pago   : $Pedido_Pago
    !Pedido_Receber: $Pedido_Receber
    !C_Ped         : $C_Ped
    ped            : $Pedido1
    bol            : $Boleto1
  }

  guid = "OhdtEyyAA-sHf_hlE2gscX7twq4"
}