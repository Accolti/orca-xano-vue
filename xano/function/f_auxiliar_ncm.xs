function f_auxiliar_ncm {
  input {
  }

  stack {
    db.query Material {
      return = {
        type : "aggregate"
        group: {Material_ncm1: $db.Material.ncm}
      }
    } as $Material1
  
    !db.transaction {
      stack {
        db.query Material {
          return = {type: "list"}
        } as $Material1
      
        foreach ($Material1) {
          each as $item {
            var $ncm {
              value = $item.ncm
            }
          
            api.lambda {
              code = """
                /**
                 * Remove todos os pontos de uma string.
                 * @param {string} texto - A string original com pontos.
                 * @return {string} A string sem nenhum ponto.
                 */
                function removerPontos(texto) {
                  if (typeof texto !== 'string') return texto;
                  // O /g garante que TODOS os pontos sejam removidos, não apenas o primeiro
                  return texto.replace(/\./g, '');
                }
                
                const ncm = $var.ncm || "";
                return removerPontos(ncm);
                """
              timeout = 10
            } as $novo
          
            var $new_ncm {
              value = $novo
            }
          
            !debug.stop {
              value = $new_ncm
            }
          
            db.edit Material {
              field_name = "id"
              field_value = $item.id
              data = {ncm: $novo}
            } as $Material2
          }
        }
      }
    }
  }

  response = $Material1
  guid = "rL35oNHAB3Sypp5L-UFO29ne5LY"
}