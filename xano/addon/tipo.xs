addon Tipo {
  input {
    int Tipo_id? {
      table = "Tipo"
    }
  }

  stack {
    db.query Tipo {
      where = $db.Tipo.id == $input.Tipo_id
      return = {type: "single"}
    }
  }

  guid = "X--UwCbB_KS4Eh2XdrSMKzzLTlY"
}