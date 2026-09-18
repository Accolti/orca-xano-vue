// Add Boleto record
query boleto verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    dblink {
      table = "Boleto"
      override = {user_id: {hidden: true}}
    }
  }

  stack {
    db.add Boleto {
      enforce_hidden_fields = false
      data = {
        created_at: "now"
        vencimento: $input.vencimento
        pagamento : $input.pagamento
        valor     : $input.valor
        obs       : $input.obs
        pedido_id : $input.pedido_id
        user_id   : $auth.id
      }
    } as $boleto
  }

  response = $boleto
  guid = "5ca7SgLjWztzyBXPGj73topJ-iQ"
}