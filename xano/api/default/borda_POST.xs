// Add borda record
query borda verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Borda"
    }
  }

  stack {
    db.add Borda {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $borda
  }

  response = $borda
  guid = "zVc94Nfhsa8f_3RwiMZqt61RuDk"
}