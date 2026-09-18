query primeiro_api_endpoint verb=GET {
  api_group = "Admim"

  input {
    text nome_do_Item? filters=trim
    decimal valor_Vnd?
  }

  stack {
    db.query "" {
      where = $db.Items.nome == $input.nome_do_Item && $db.Items.preco >= $input.valor_Vnd
      return = {type: "list"}
    } as $Items_1
  
    math.mul $valor_Vnd {
      value = "valor_Vnd"
    }
  
    db.query User {
      return = {type: "list"}
    } as $User_1
  }

  response = {result_1: $Items_1, User_1: $User_1}
  guid = "6DTGMpkg--Byn8JCjb3SJk_0Jzk"
}