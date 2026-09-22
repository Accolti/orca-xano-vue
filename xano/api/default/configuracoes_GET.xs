// Query all Configuracoes records
query configuracoes verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Configuracoes {
      return = {type: "list"}
      output = ["versao_materiais", "versao_produtos", "versao_taxas_banco", "taxas_atualizado_em"]
    } as $configuracoes
  }

  response = {"configuracoes-mae": $configuracoes}
  guid = "xlYtKXSVkL5QNCXzBsxRQwUS6os"
}