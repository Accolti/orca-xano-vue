// Retorna a dimensão (Largura ou Comp) referente ao múltiplo superior ou igual
function FCMultiplo {
  input {
    // Numero é o valor que o usuário quer em uma das dimensões do tapete
    decimal Numero?
  
    // VAlor do multiplo em metro
    decimal valorDoMultiplo?
  }

  stack {
    var $multiplo {
      value = $input.Numero
        |divide:$input.valorDoMultiplo
        |ceil
        |multiply:$input.valorDoMultiplo
        |round:2
    }
  }

  response = {Valor: $multiplo}
  guid = "F1tjyNiJ8pXX8uKgudo_8cX5ygk"
}