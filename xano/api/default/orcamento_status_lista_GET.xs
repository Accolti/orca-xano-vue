// novo-sis: retorna o status de todos os orçamentos do usuário para a listagem.
// db.query simples SEM output restritivo (o enum status só retorna bem assim),
// evitando o erro "Unsupported parameter reference" do output paginado.
query orcamento_status_lista verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Orca {
      where = $db.Orca.user_id ==? $auth.id
      return = {type: "list"}
    } as $Orca_lista
  }

  response = $Orca_lista
  tags = ["orcamento", "novo-sis"]
  guid = "orcamento-status-lista-novo-sis-0001"
}