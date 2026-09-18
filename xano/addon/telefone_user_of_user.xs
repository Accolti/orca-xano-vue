addon Telefone_User_of_User {
  input {
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.query Telefone_User {
      where = $db.Telefone_User.user_id == $input.user_id
      return = {type: "list"}
    }
  }

  guid = "Ka9WvCEJoibM0AMbhqs34qZpg3I"
}