// Resolve o id numérico do orçamento a partir do cod_orca — leve, sem joins.
// novo-sis: substitui a dependência do Orcamento_Detalhes (legado) no fluxo de edição.
query orca_por_codigo verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text cod_orca? filters=trim
  }

  stack {
    db.query Orca {
      where = $db.Orca.cod_orca == $input.cod_orca && $db.Orca.user_id == $auth.id
      return = {type: "single"}
      output = ["id", "cod_orca", "cliente_id"]
    } as $Orca_1
  }

  response = {
    id        : $Orca_1.id
    cod_orca  : $Orca_1.cod_orca
    cliente_id: $Orca_1.cliente_id
  }

  tags = ["orcamento", "novo-sis"]
  guid = "orca-por-codigo-novo-sis-0001"
}