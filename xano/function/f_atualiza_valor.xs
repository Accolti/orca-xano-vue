function f_atualizaValor {
  input {
  }

  stack {
    // Atualização em 01/04/2025 em 1.10 ou seja 10% em media
    !var $Atualizacao {
      value = ""
    }
  
    db.transaction {
      stack {
        db.query Produto {
          return = {type: "list"}
        } as $Produto1
      
        foreach ($Produto1) {
          each as $item {
            !debug.stop {
              value = $item
            }
          
            db.edit Produto {
              field_name = "id"
              field_value = $item.id
              enforce_hidden_fields = false
              data = {valor: $item.valor|divide:1.1}
            } as $Produto2
          
            !debug.stop {
              value = $item
            }
          }
        }
      }
    }
  
    !db.transaction {
      stack {
        db.query Borda {
          return = {type: "list"}
        } as $Borda1
      
        foreach ($Borda1) {
          each as $item {
            db.add_or_edit Borda {
              field_name = "id"
              field_value = $item.id
              enforce_hidden_fields = false
              data = {valor: $item.valor|divide:1.1}
            } as $Borda2
          }
        }
      }
    }
  
    !db.transaction {
      stack {
        db.query Variacao {
          return = {type: "list"}
        } as $Variacao1
      
        foreach ($Variacao1) {
          each as $item {
            db.edit Variacao {
              field_name = "id"
              field_value = $item.id
              enforce_hidden_fields = false
              data = {valor_custo: $item.valor_custo|multiply:1.1}
            } as $Variacao2
          }
        }
      }
    }
  }

  response = $Variacao2
  guid = "VUzJ1LamYpzdizvZrrZshimrXvc"
}