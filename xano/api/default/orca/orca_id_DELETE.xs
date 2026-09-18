// Delete Orca record.
query "orca/{orca_id}" verb=DELETE {
  api_group = "Default"

  input {
    int orca_id? filters=min:1
  }

  stack {
    db.del Orca {
      field_name = "id"
      field_value = $input.orca_id
    }
  }

  response = null
  guid = "uFhneJtnSFUFj52l5qRaSvxHCxc"
}