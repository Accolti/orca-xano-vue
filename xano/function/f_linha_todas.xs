function f_linha_todas {
  input {
  }

  stack {
    db.query Linha {
      return = {type: "list"}
    } as $linha
  }

  response = $linha
  guid = "XnJ7mX84sY9A8Gdzbjhdt2QlsGs"
}