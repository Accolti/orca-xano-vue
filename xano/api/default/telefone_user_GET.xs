// Query all telefone_user records
query telefone_user verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query telefone_user {
      return = {type: "list"}
    } as $telefone_user
  }

  response = $telefone_user
  guid = "GukvxQxFtuzeJHozXnUBt-gtiVU"
}