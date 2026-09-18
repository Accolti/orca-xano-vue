// Converte 100 em 2 
// 85 em 1.85
function Marguem_Multiplicadora {
  input {
    decimal Marguem?
  }

  stack {
    var $Marguem_Mult {
      value = $input.Marguem|divide:100|add:1
    }
  }

  response = $Marguem_Mult
  guid = "botNcvoa5OsZGWLhd1OkaM5XZ58"
}