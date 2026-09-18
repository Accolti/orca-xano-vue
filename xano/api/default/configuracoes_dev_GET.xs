// Lista as Configuracoes (versão materiais/produtos) com id — usada pela dev tool
// de Configurações (auth User) para exibir e editar as versões do catálogo.
query configuracoes_dev verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Configuracoes {
      sort = {id: "asc"}
      return = {type: "list"}
    } as $configuracoes
  }

  response = $configuracoes
  guid = "OrcaKap-configuracoes-dev"
}