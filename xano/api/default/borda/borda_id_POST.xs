// Edit borda record
query "borda/{borda_id}" verb=POST {
  api_group = "Default"

  input {
    int borda_id? filters=min:1
    dblink {
      table = "Borda"
    }
  }

  stack {
    db.edit Borda {
      field_name = "id"
      field_value = $input.borda_id
      enforce_hidden_fields = false
      data = {}
    } as $borda
  }

  response = $borda
  guid = "-pdldP4Fs1nfHqIBlCL_DCwldNs"
}