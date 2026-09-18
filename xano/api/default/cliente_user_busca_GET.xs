query cliente_user_busca verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text busca? filters=trim
    int pagina? filters=min:1
  }

  stack {
    db.query Cliente {
      where = ($db.Cliente.user_id == $auth.id)
      sort = {Cliente.created_at: "desc"}
      return = {type: "list"}
    } as $todos_clientes
  
    api.lambda {
      code = """
        // Pega os dados enviados para o Lambda
        const busca = $input.busca ? $input.busca.trim() : '';
        const listaClientes = $var.todos_clientes || [];
        
        const limite = 15;
        const pagina = Math.max(1, parseInt($input.pagina, 10) || 1);
        
        // Função para remover acentos e transformar em minúsculo
        const limparTexto = (str) => {
          if (!str) return '';
          return str
            .toString()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .toLowerCase();
        };
        
        // Função para manter apenas os números (limpa . / - de CNPJ/CPF)
        const limparNumeros = (str) => {
          if (!str) return '';
          return str.toString().replace(/\D/g, '');
        };
        
        const termoTexto = limparTexto(busca);
        const termoNumero = limparNumeros(busca);
        
        // Sem busca → retorna todos; com busca → filtro inteligente (texto ou número)
        let resultado;
        if (!busca) {
          resultado = listaClientes;
        } else {
          resultado = listaClientes.filter((cliente) => {
            const razao = limparTexto(cliente.razao_social);
            const fantasia = limparTexto(cliente.nome_fantasia);
            const contato = limparTexto(cliente.contato);
            const email = limparTexto(cliente['e-mail'] || cliente.email);
            const cnpj = limparNumeros(cliente.cnpj);
            const cpf = limparNumeros(cliente.cpf);
        
            // Busca por Texto (Razão Social, Nome Fantasia, Contato, Email)
            const achouTexto =
              termoTexto &&
              (razao.includes(termoTexto) ||
                fantasia.includes(termoTexto) ||
                contato.includes(termoTexto) ||
                email.includes(termoTexto));
        
            // Busca por Número (CNPJ ou CPF limpos)
            const achouNumero =
              termoNumero.length > 0 &&
              (cnpj.includes(termoNumero) || cpf.includes(termoNumero));
        
            return achouTexto || achouNumero;
          });
        }
        
        // Paginação de 15 por página (ordenados por created_at desc no db.query)
        const total = resultado.length;
        const inicio = (pagina - 1) * limite;
        const cliente = resultado.slice(inicio, inicio + limite);
        
        return { cliente, total, pagina, limite };
        """
      timeout = 10
    } as $x1
  }

  response = $x1
  guid = "kPswZ_aBjk2MyBt9xnegqEU-wuo"
}