// Add Forma_Pagamento record
query forma_pagamento verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "Forma_Pagamento"
    }
  }

  stack {
    db.add Forma_Pagamento {
      enforce_hidden_fields = false
      data = {created_at: "now"}
    } as $forma_pagamento
  }

  response = $forma_pagamento
  guid = "C5E8hv3HWiXcsYclViBzOn8qJE0"
}