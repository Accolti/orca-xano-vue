// Edit Boleto record
query "boleto/{boleto_id}" verb=PATCH {
  api_group = "Default"
  auth = "User"

  input {
    int boleto_id? filters=min:1
    dblink {
      table = "Boleto"
      override = {user_id: {hidden: true}, pedido_id: {hidden: true}}
    }
  }

  stack {
    db.edit Boleto {
      field_name = "id"
      field_value = $input.boleto_id
      enforce_hidden_fields = false
      data = {
        vencimento: $input.vencimento
        pagamento : $input.pagamento
        valor     : $input.valor
        obs       : $input.obs
      }
    } as $boleto
  }

  response = $boleto
  guid = "rZ7oSlO_9dMJweB7HBhcI_aeWtQ"
}