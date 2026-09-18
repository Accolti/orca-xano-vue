// Query all TestWithDate records
query testwithdate verb=GET {
  api_group = "Default"

  input {
  }

  stack {
    db.query TestWithDate {
      return = {type: "list"}
    } as $testwithdate
  }

  response = $testwithdate
  guid = "ak0DACf1VEBlvpWDG15Nbuywqd4"
}