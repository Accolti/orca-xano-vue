// Edit Forma_Pagamento record
query "forma_pagamento/{forma_pagamento_id}" verb=PATCH {
  api_group = "Default"

  input {
    int forma_pagamento_id? filters=min:1
    dblink {
      table = "Forma_Pagamento"
    }
  }

  stack {
    util.get_raw_input {
      encoding = "json"
      exclude_middleware = false
    } as $raw_input
  
    db.patch Forma_Pagamento {
      field_name = "id"
      field_value = $input.forma_pagamento_id
      data = `$input|pick:($raw_input|keys)`|filter_null|filter_empty_text
    } as $forma_pagamento
  }

  response = $forma_pagamento
  guid = "D2K3yuojRrqLTq4qHs2Awi8dkMQ"
}