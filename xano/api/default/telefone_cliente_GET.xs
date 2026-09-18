// Query all telefone_cliente records
query telefone_cliente verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Telefone_Cliente {
      return = {type: "list"}
    } as $telefone_cliente
  }

  response = $telefone_cliente
  guid = "_0TdIwoQhJR4uGcvzOj5bhaexAE"
}