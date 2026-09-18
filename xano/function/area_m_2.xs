function AreaM2 {
  input {
    decimal Larg?
    decimal Comp?
  }

  stack {
    var $AreaQuadrada {
      value = $input.Larg|multiply:$input.Comp
    }
  }

  response = {AreaM2: $AreaQuadrada}
  guid = "rjrrOdSJbOGydA57zRwjxV1ugG0"
}