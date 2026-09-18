addon Nivel {
  input {
    int Nivel_id? {
      table = "Nivel"
    }
  }

  stack {
    db.query Nivel {
      where = $db.Nivel.id == $input.Nivel_id
      return = {type: "single"}
    }
  }

  guid = "s1Kd1tbbNdgLGSFZj7MfFpuxzKo"
}