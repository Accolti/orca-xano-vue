// Query all produto_all_indice records
query produto_all_indice verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query "" {
      return = {type: "list"}
    } as $produto_all_indice
  }

  response = $produto_all_indice
  guid = "s12NVUwhkiFp7I_wHobaoD3k3xE"
}