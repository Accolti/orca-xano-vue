// Add telefone_cliente record
query telefone_cliente verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Telefone_Cliente"
    }
  }

  stack {
    db.add Telefone_Cliente {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $telefone_cliente
  }

  response = $telefone_cliente
  guid = "I06YnpYDig-t67mCwVc1Mr8CVIY"
}