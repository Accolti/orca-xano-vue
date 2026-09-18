addon Cliente {
  input {
    int Cliente_id? {
      table = "Cliente"
    }
  }

  stack {
    db.query Cliente {
      where = $db.Cliente.id == $input.Cliente_id
      return = {type: "single"}
    }
  }

  guid = "0NqujI-V10SuTL9B18iZgNSXal0"
}