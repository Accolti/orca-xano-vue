// Marca as notificações do usuário como lidas (todas).
query notificacoes_marcar_lida verb=POST {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Notificacao {
      where = $db.Notificacao.user_id == $auth.id && $db.Notificacao.lida != true
      return = {type: "list"}
      output = ["id"]
    } as $abertas
  
    foreach ($abertas) {
      each as $n {
        db.edit Notificacao {
          field_name = "id"
          field_value = $n.id
          enforce_hidden_fields = false
          data = {lida: true, data_leitura: "now"}
        } as $editada
      }
    }
  }

  response = {ok: true}
  tags = ["notificacao", "f3"]
  guid = "notificacoes-marcar-lida-f3-0001"
}