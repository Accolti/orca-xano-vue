// Add Tipo_Telefone record
query tipo_telefone verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Tipo_Telefone"
    }
  }

  stack {
    db.add Tipo_Telefone {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $tipo_telefone
  }

  response = $tipo_telefone
  guid = "xIlX-9vKgAnHM1DECiqdE34rPpo"
}