// Notificações do usuário logado (mais recentes). Retorna lista + contagem não lidas.
query notificacoes verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int limite? filters=min:1
  }

  stack {
    db.query Notificacao {
      join = {
        Orca: {
          table: "Orca"
          type : "left"
          where: $db.Notificacao.orca_id == $db.Orca.id
        }
      }
    
      where = $db.Notificacao.user_id == $auth.id
      sort = {created_at: "desc"}
      eval = {cod_orca: $db.Orca.cod_orca}
      return = {type: "list"}
      output = [
        "id"
        "user_id"
        "tipo"
        "orca_id"
        "lida"
        "created_at"
        "cod_orca"
      ]
    } as $notifs
  
    db.query Notificacao {
      where = $db.Notificacao.user_id == $auth.id && $db.Notificacao.lida != true
      return = {type: "list"}
    } as $naoLidas
  }

  response = {notificacoes: $notifs, nao_lidas: $naoLidas|count}
  tags = ["notificacao", "f3"]
  guid = "notificacoes-f3-0001"
}