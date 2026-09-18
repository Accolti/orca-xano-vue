// Query all borda records
query borda verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Borda {
      return = {type: "list"}
    } as $borda
  }

  response = $borda
  guid = "P8_NyLp95cP3zhoJT9obwe1NSwQ"
}