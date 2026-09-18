// Delete Forma_Pagamento record.
query "forma_pagamento/{forma_pagamento_id}" verb=DELETE {
  api_group = "Default"

  input {
    int forma_pagamento_id? filters=min:1
  }

  stack {
    db.del Forma_Pagamento {
      field_name = "id"
      field_value = $input.forma_pagamento_id
    }
  }

  response = null
  guid = "Ztm8QjAMxDH78PrBZ2l5tC-6FA0"
}