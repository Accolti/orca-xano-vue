// Get Forma_Pagamento record
query "forma_pagamento/{forma_pagamento_id}" verb=GET {
  api_group = "Default"

  input {
    int forma_pagamento_id? filters=min:1
  }

  stack {
    db.get Forma_Pagamento {
      field_name = "id"
      field_value = $input.forma_pagamento_id
    } as $forma_pagamento
  
    precondition ($forma_pagamento != null) {
      error_type = "notfound"
      error = "Not Found."
    }
  }

  response = $forma_pagamento
  guid = "4n2FwK35mxTBy_62HT-bi1ekYtk"
}