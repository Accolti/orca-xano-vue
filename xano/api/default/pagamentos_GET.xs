// novo-sis: lista as parcelas financeiras do usuário com info do orçamento (Orca)
// e a forma de pagamento. Filtro por status é feito no frontend.
query pagamentos verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    db.query Boleto {
      join = {
        Orca           : {table: "Orca", where: $db.Boleto.orca_id == $db.Orca.id}
        Forma_Pagamento: {
          table: "Forma_Pagamento"
          where: $db.Boleto.forma_pagamento_id == $db.Forma_Pagamento.id
        }
      }
    
      where = $db.Boleto.user_id == $auth.id && $db.Boleto.orca_id ==? $input.orca_id
      sort = {Boleto.vencimento: "asc"}
      eval = {
        cod_orca  : $db.Orca.cod_orca
        eh_pedido : $db.Orca.eh_pedido
        forma     : $db.Forma_Pagamento.tipo
        cliente_id: $db.Orca.cliente_id
      }
    
      return = {type: "list"}
      output = [
        "id"
        "orca_id"
        "vencimento"
        "pagamento"
        "valor"
        "forma_pagamento_id"
        "user_id"
        "cod_orca"
        "eh_pedido"
        "forma"
        "cliente_id"
      ]
    } as $parcelas
  }

  response = $parcelas
  tags = ["pagamento", "novo-sis"]
  guid = "pagamentos-novo-sis-0001"
}