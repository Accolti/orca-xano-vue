// Lista os provedores de taxas que devem ser coletados automaticamente (cron).
// Autenticação por token de serviço (env `coleta_secret`). Endpoint público + token.
query taxas_coleta_provedores verb=GET {
  api_group = "Default"

  input {
    text token? filters=trim
  }

  stack {
    precondition ($input.token != null && $input.token != "" && $input.token == $env.workspace.coleta_secret) {
      error_type = "accessdenied"
      error = "Token inválido."
    }
  
    db.query Provedor {
      where = $db.Provedor.ativo == true && $db.Provedor.metodo != null && $db.Provedor.metodo != "manual"
      sort = {Provedor.nome: "asc"}
      return = {type: "list"}
      output = ["id", "nome", "url_taxas", "metodo", "canal_default", "seletor", "ultima_coleta"]
    } as $provedores
  }

  response = {provedores: $provedores}
  tags = ["novo-sis", "taxas", "coleta"]
  guid = "taxas-coleta-provedores-0001"
}
