query item_ped verb=POST {
  api_group = "Default"

  input {
    dblink {
      table = "item_ped"
    }
  }

  stack {
    function.run item_ped_func {
      input = {item_ped__: $input.item_ped__}
    } as $func_1
  }

  response = $func_1
  guid = "jU6g2Dq5IioHxd_5qthgCJQACNw"
}