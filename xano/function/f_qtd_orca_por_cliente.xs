// retorna a qtd de orçamentos por cliente.
// O cliente só pode ser excluido se não houver nenhum orçamento
function fQtd_Orca_por_cliente {
  input {
    int cliente_id? {
      table = "Cliente"
    }
  }

  stack {
    db.query Orca {
      where = $db.Orca.cliente_id == $input.cliente_id
      return = {type: "count"}
    } as $Orca_Count
  }

  response = $Orca_Count
  tags = ["orcamento", "cliente"]
  guid = "hsJyX3bflRjWK-57EzW1WAu0tR4"
}