// Add preco_produto record
query preco_produto verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "preco_produto"
    }
  }

  stack {
    db.add preco_produto {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $preco_produto
  }

  response = $preco_produto
  guid = "AEkNd-zbWKDYGVa5aX0sF1bUOZo"
}