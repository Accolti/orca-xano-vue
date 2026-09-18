// Query all Mercado records
query mercado verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Mercado {
      return = {type: "list"}
    } as $mercado
  }

  response = $mercado
  guid = "MZz0D7hWbmJ2YEaHCa5mKH3ojuo"
}