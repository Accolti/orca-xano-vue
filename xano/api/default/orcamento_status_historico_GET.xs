// novo-sis: retorna o histórico de status de um orçamento (auditoria), do mais recente ao mais antigo.
// Fonte: tabela Orca_Status_Log (append-only, escrita por orcamento_status / orcamento_converter_pedido).
query orcamento_status_historico verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    db.query Orca_Status_Log {
      where = $db.Orca_Status_Log.orca_id == $input.orca_id
      sort = {created_at: "desc"}
      return = {type: "list"}
    } as $historico
  }

  response = $historico
  tags = ["orcamento", "novo-sis"]
  guid = "orcamento-status-historico-novo-sis-0001"
}