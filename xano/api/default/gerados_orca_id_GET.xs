// Query all Gerados records
query gerados_orca_id verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    enum tipo? {
      values = ["pdf", "whats"]
    }
  }

  stack {
    db.query Gerados {
      where = $db.Gerados.orca_id == $input.orca_id && $db.Gerados.tipo ==? $input.tipo
      sort = {gerados.created_at: "desc"}
      return = {type: "list"}
    } as $gerados
  }

  response = $gerados
  guid = "xs9O9h9TqA71VLpsxNJLUyBi6PE"
}