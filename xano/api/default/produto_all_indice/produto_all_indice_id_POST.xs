// Edit produto_all_indice record
query "produto_all_indice/{produto_all_indice_id}" verb=POST {
  api_group = "Default"

  input {
    int produto_all_indice_id? filters=min:1
    dblink {
      table = ""
    }
  }

  stack {
    db.edit "" {
      field_name = "id"
      field_value = $input.produto_all_indice_id
      enforce_hidden_fields = false
      data = {}
    } as $produto_all_indice
  }

  response = $produto_all_indice
  guid = "Gnw06D0N7Lb0mtUr-uGAnVpYwmE"
}