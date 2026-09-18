function f_auxiliar_alterar_material {
  input {
    json[] dados?
  }

  stack {
    !db.query Material {
      return = {type: "list"}
    } as $Material1
  
    debug.stop {
      value = $input.dados
    }
  
    var $atualizado {
      value = []
    }
  
    db.transaction {
      stack {
        foreach ($input.dados) {
          each as $item {
            db.query Material {
              where = ($db.Material.nome|to_upper) == ($item.nome_produto|to_upper)
              return = {type: "list"}
            } as $Material2
          
            conditional {
              if (($Material2|count) == 1) {
                db.edit Material {
                  field_name = "id"
                  field_value = $Material2.id|first
                  data = {
                    garantia  : $item.garantia_meses
                    ncm       : $item.ncm
                    ipi       : $item.ipi
                    st        : $item.st
                    importado : $item.importado
                    updated_at: now
                  }
                } as $Material1
              
                var.update $atualizado {
                  value = $atualizado|push:$Material2.id
                }
              }
            }
          }
        }
      }
    }
  }

  response = {atualizado: $atualizado, material: $Material1}
  guid = "HNMZ1e2YoeUisTn_XWXf7TGomho"
}