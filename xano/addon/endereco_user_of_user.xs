addon endereco_user_of_User {
  input {
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.query endereco_user {
      where = $db.endereco_user.user_id == $input.user_id
      return = {type: "single"}
    }
  }

  guid = "lppxnOXIeWk6UT_17GgTFPlr0sw"
}