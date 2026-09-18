// Query all Unidade records
query unidade verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Unidade {
      return = {type: "list"}
    } as $unidade
  }

  response = $unidade
  guid = "5qcKKha-xFzUdSgTCCYqvgmLPYQ"
}