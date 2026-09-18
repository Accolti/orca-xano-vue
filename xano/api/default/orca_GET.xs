// Query all Orca records
query orca verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Orca {
      where = $db.Orca.user_id == $auth.id
      return = {type: "list"}
    } as $orca
  }

  response = $orca
  guid = "ldoFkNFnkj4fVN6YXMTqAI6p4yk"
}