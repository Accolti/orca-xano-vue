// Acha o comprimento em metros para uma área dada pelo cliente. e uma largura fixa do rolo. Rubberkap, Grama etc...
function "Comprimento=Area_Div_LarguraFixa" {
  input {
    decimal Area?
    decimal Larg_Fixa?
  
    // Tamanho do Rolo em Metros
    int Tam_do_Rolo?
  }

  stack {
    // o resuldado de 8.4 / 1.2 deveria dar exatamente 7.00 porém seu resultado dá 7.00000000001 quando é chamado o ceil ela abaca arrendondado para 8, quando deveria arrendondar para 7. Enttão fiz um round de 2 para que o resultado chegue no valor correto.
    var $Comp {
      value = $input.Area
        |divide:$input.Larg_Fixa
        |round:2
        |ceil
    }
  }

  response = $Comp
  guid = "7T-7qwSwdIMXltgBfnLLtw8wEb0"
}