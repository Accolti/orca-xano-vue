function fBuscarProduto {
  input {
    text busca? filters=trim
  }

  stack {
    // Comentário
  
    db.query Produto {
      join = {
        Material: {
          table: "Material"
          where: $db.Produto.material_id == $db.Material.id
        }
        Linha   : {
          table: "Linha"
          type : "left"
          where: $db.Produto.linha_id ==? $db.Linha.id
        }
        Tipo    : {
          table: "Tipo"
          type : "left"
          where: $db.Produto.tipo_id ==? $db.Tipo.id
        }
        Nivel   : {
          table: "Nivel"
          type : "left"
          where: $db.Produto.nivel_id ==? $db.Nivel.id && $db.Produto.linha_id ==? $db.Nivel.linha_id && $db.Produto.tipo_id ==? $db.Nivel.tipo_id
        }
        Borda   : {
          table: "Borda"
          type : "left"
          where: $db.Produto.material_id ==? $db.Borda.material_id && $db.Borda.ativo ==? true
        }
      }
    
      sort = {Produto.id: "asc"}
      eval = {
        produto           : $db.Material.nome|concat:" "|concat:$db.Linha.nome|concat:" "|concat:$db.Tipo.nome|concat:" "|concat:$db.Nivel.nome|concat:" "|concat:$db.Borda.nome
        borda_custo       : $db.Borda.valor
        borda_base_calculo: $db.Borda.Unidade
        produto_id        : $db.Produto.id
        borda_id          : $db.Borda.id
        ncm               : $db.Material.ncm
        imp               : $db.Material.imp
        ipi               : $db.Material.ipi
      }
    
      return = {type: "list", distinct: "yes"}
      output = [
        "id"
        "material_id"
        "classificacao_id"
        "linha_id"
        "tipo_id"
        "nivel_id"
        "valor"
        "Unidade"
        "Base_de_Calculo"
        "created_at"
        "detalhe_id"
        "classificacao"
        "produto"
        "borda_custo"
        "borda_base_calculo"
        "produto_id"
        "borda_id"
        "ncm"
        "imp"
        "ipi"
      ]
    
      addon = [
        {
          name : "Variacao_of_Detalhe"
          input: {detalhe_id: $output.detalhe_id}
          as   : "_variacao_of_detalhe"
        }
      ]
    } as $prd
  
    api.lambda {
      code = """
        // Pega os dados enviados para o Lambda
        const busca = $input.busca ? $input.busca.trim() : '';
        const listaProdutos = $var.prd || [];
        
        
        return buscarProdutosFuzzy(busca,listaProdutos);
        
        /**
         * Busca produtos permitindo termos em qualquer ordem e aceitando
         * erros leves de digitação ou variações (ex: "Pintado" -> "Printado").
         * 
         * @param {string} termoBusca - Termo digitado pelo usuário
         * @param {Array} listaProdutos - Lista de produtos do banco de dados
         * @returns {Array} Produtos encontrados
         */
        function buscarProdutosFuzzy(termoBusca, listaProdutos) {
          if (!termoBusca || !termoBusca.trim() || !Array.isArray(listaProdutos)) {
            return listaProdutos || [];
          }
        
          // 1. Normaliza texto (remove acentos e converte para minúsculas)
          const normalizar = (str) =>
            (str || '')
              .toString()
              .normalize('NFD')
              .replace(/[\u0300-\u036f]/g, '')
              .toLowerCase();
        
          // 2. Algoritmo para calcular a diferença de letras entre duas palavras (Levenshtein)
          const calcularDistancia = (a, b) => {
            if (a === b) return 0;
            if (!a.length) return b.length;
            if (!b.length) return a.length;
        
            const row = Array(a.length + 1).fill(0).map((_, i) => i);
            for (let i = 1; i <= b.length; i++) {
              let prev = i;
              for (let j = 1; j <= a.length; j++) {
                const val = b[i - 1] === a[j - 1] ? row[j - 1] : Math.min(row[j - 1], row[j], prev) + 1;
                row[j - 1] = prev;
                prev = val;
              }
              row[a.length] = prev;
            }
            return row[a.length];
          };
        
          // 3. Quebra a busca do usuário em termos soltos
          const tokensBusca = normalizar(termoBusca).split(/\s+/).filter(Boolean);
        
          return listaProdutos.filter((item) => {
            const textoCompleto = normalizar(`${item.produto} ${item.classificacao}`);
            const palavrasProduto = textoCompleto.split(/\s+/).filter(Boolean);
        
            // Cada palavra digitada precisa casar (exata ou aproximadamente) com o produto
            return tokensBusca.every((token) => {
              // A) Checagem exata/substring (muito rápida)
              if (textoCompleto.includes(token)) return true;
        
              // B) Tolerância ajustável conforme o tamanho da palavra:
              // - Palavras com 4 a 6 letras: tolera 1 erro de digitação
              // - Palavras com 7+ letras: tolera até 2 erros (ex: "pintado" vs "printado")
              const limiteErros = token.length > 6 ? 2 : token.length >= 4 ? 1 : 0;
        
              // Compara a palavra digitada com cada palavra do produto
              return palavrasProduto.some((palavraProd) => {
                const distancia = calcularDistancia(token, palavraProd);
                return distancia <= limiteErros;
              });
            });
          });
        }
        """
      timeout = 10
    } as $retFiltro
  }

  response = {prds: $retFiltro}
  guid = "yj2mafxpouytIuJ8KaurAMvMhLg"
}