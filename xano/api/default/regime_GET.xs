// Query all Regime records
query regime verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query Regime {
      return = {type: "list"}
    } as $regime
  }

  response = $regime
  guid = "1mSi4mjRWwUGMoZS2GhjHUnkjgI"
}