// Delete borda record.
query "borda/{borda_id}" verb=DELETE {
  api_group = "Default"

  input {
    int borda_id? filters=min:1
  }

  stack {
    db.del Borda {
      field_name = "id"
      field_value = $input.borda_id
    }
  }

  response = null
  guid = "qAcfb8S9wQ1QjJVr73oNCM3B_Jk"
}