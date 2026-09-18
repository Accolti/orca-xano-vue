// Query all Forma_Pagamento records
query forma_pagamento verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Forma_Pagamento {
      return = {type: "list"}
    } as $forma_pagamento
  }

  response = $forma_pagamento
  guid = "4-FtmfOHUwyRFgP3wsCRs1Z77mQ"
}