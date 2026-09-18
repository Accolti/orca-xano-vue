// Add Aliquotas_icms record
query aliquotas_icms verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Aliquotas_icms"
    }
  }

  stack {
    db.add Aliquotas_icms {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $aliquotas_icms
  }

  response = $aliquotas_icms
  guid = "g8Ury2jeclpOX1kk-WjqLOsEtO0"
}