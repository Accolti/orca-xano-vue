// Delete Aliquotas_icms record.
query "aliquotas_icms/{aliquotas_icms_id}" verb=DELETE {
  api_group = "Default"

  input {
    int aliquotas_icms_id? filters=min:1
  }

  stack {
    db.del Aliquotas_icms {
      field_name = "id"
      field_value = $input.aliquotas_icms_id
    }
  }

  response = null
  guid = "Wpsu04hztVuRzeMG7Ua904iDsAo"
}