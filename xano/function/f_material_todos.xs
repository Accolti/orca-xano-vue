// Função que busca todos os materiais
function f_material_todos {
  input {
  }

  stack {
    // 1. Busca todos os materiais
    db.query Material {
      where = $db.Material.ativo == true
      sort = {Material.Ordenacao: "asc", Material.nome: "asc"}
      eval = {
        material_filho_id: $db.Material.material_id
        material_id      : $db.Material.id
      }
    
      return = {type: "list"}
      output = [
        "id"
        "nome"
        "Ordenacao"
        "created_at"
        "ativo"
        "descricao"
        "ncm"
        "imp"
        "ipi"
        "peso"
        "st"
        "nac"
        "Observacao"
        "organizacao_id"
        "updated_at"
        "material_filho_id"
        "material_id"
        "garantia"
      ]
    } as $material
  
    // 2. Cria uma lista vazia para guardar os resultados do loop
    var $lista_suc {
      value = []
    }
  
    // 3. Loop pelos materiais para rodar a função em cada um
    foreach ($material) {
      each as $item {
        function.run Ret_TabMaeEFilhas_2 {
          input = {
            id_material   : $item.id
            id_organizacao: $item.organizacao_id
            nmMaterial    : null
          }
        } as $suc
      
        // Adiciona a resposta $suc na lista acumuladora
        var.update $lista_suc {
          value = $lista_suc|push:$suc
        }
      }
    }
  
    // 4. Processa TUDO de uma só vez no Lambda após o término do loop
    api.lambda {
      code = """
        
        let suc=$var.lista_suc;
        let mat=$var.material;
        
        return mesclarMateriaisESucessoras(suc,mat);
        
        
        function mesclarMateriaisESucessoras(arrayAcessorios, arrayMateriais) {
          // 1. Cria um mapa de busca indexado pelo Material_id
          const mapaSuc = {};
        
          arrayAcessorios.forEach((item) => {
            // Pega o conteúdo de Material_1 (ou qualquer outra chave equivalente)
            const listaInterna = Object.values(item)[0];
        
            // Se houver dados dentro do array, extrai os atributos
            if (Array.isArray(listaInterna) && listaInterna.length > 0) {
              const dados = listaInterna[0];
              
              mapaSuc[dados.Material_id] = {
                Linha: dados.Linha,
                Tipo: dados.Tipo,
                Nivel: dados.Nivel,
                Borda: dados.Borda,
                Variacao: dados.Variacao
              };
            }
          });
        
          // 2. Mapeia o array principal de materiais injetando o objeto "suc"
          return arrayMateriais.map((material) => {
            return {
              ...material,
              suc: mapaSuc[material.id] || null // Retorna o objeto suc ou null se não houver
            };
          });
        }
        """
      timeout = 10
    } as $resultado_materiais
  }

  response = $resultado_materiais
  guid = "tHoIoGAA-6QZY8FLSQCUoPhp7Go"
}