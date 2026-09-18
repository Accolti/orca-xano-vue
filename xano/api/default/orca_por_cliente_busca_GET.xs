// Query all Orca records
query orca_por_cliente_busca verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text busca? filters=trim
    int page?=1
    int per_page?=20
  
    // true → retorna apenas Orcas convertidas em pedido (eh_pedido == true)
    bool so_pedidos?
  
    // true → retorna apenas orçamentos (eh_pedido != true). Se ambos null → tudo.
    bool somente_orcamentos?
  }

  stack {
    db.query Orca {
      join = {
        Cliente: {
          table: "Cliente"
          type : "left"
          where: $db.Orca.cliente_id ==? $db.Cliente.id
        }
      }
    
      where = $db.Orca.user_id ==? $auth.id && (($input.so_pedidos && $db.Orca.eh_pedido) || ($input.somente_orcamentos && $db.Orca.eh_pedido != true) || ($input.so_pedidos != true && $input.somente_orcamentos != true)) && (($db.Cliente.nome_fantasia|unaccent|to_upper) includes? ($input.busca|unaccent|to_upper) || ($db.Cliente.razao_social|unaccent|to_upper) includes? ($input.busca|unaccent|to_upper) || ($db.Orca.cod_orca|unaccent|to_upper) includes? ($input.busca|unaccent|to_upper) || ($db.Cliente.cnpj|unaccent|to_upper) includes? ($input.busca|unaccent|to_upper) || ($db.Cliente.cpf|unaccent|to_upper) includes? ($input.busca|unaccent|to_upper) || ($db.Cliente.contato|unaccent|to_upper) includes? ($input.busca|unaccent|to_upper))
      sort = {Orca.created_at: "desc"}
      eval = {
        nome_fantasia     : $db.Cliente.nome_fantasia
        razao_social      : $db.Cliente.razao_social
        contato           : $db.Cliente.contato
        cpf               : $db.Cliente.cpf
        cnpj              : $db.Cliente.cnpj
        inscricao_estadual: $db.Cliente.inscricao_estadual
      }
    
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per_page}
      }
    
      output = [
        "itemsReceived"
        "curPage"
        "nextPage"
        "prevPage"
        "offset"
        "itemsTotal"
        "pageTotal"
        "items.id"
        "items.created_at"
        "items.cod_orca"
        "items.cliente_id"
        "items.frtB2B"
        "items.frtB2C"
        "items.validade"
        "items.user_id"
        "items.margem"
        "items.cst_tot"
        "items.luc_tot"
        "items.vnd_tot"
        "items.vnd_B2B_tot"
        "items.vnd_B2B_B2C_tot"
        "items.desconto"
        "items.eh_pedido"
        "items.data_envio"
        "items.data_aprovacao"
        "items.total_itens"
        "items.mao_de_obra"
        "items.nome_fantasia"
        "items.razao_social"
        "items.contato"
        "items.cpf"
        "items.cnpj"
        "items.iscricao_estadual"
        "items.nome"
        "items.doc"
        "items.tipo_doc"
      ]
    } as $orca
  
    !db.query Orca {
      join = {
        Cliente: {
          table: "Cliente"
          type : "left"
          where: $db.Orca.cliente_id ==? $db.Cliente.id
        }
      }
    
      where = $db.Orca.user_id ==? $auth.id
      sort = {Orca.created_at: "desc"}
      eval = {
        nome_fantasia     : $db.Cliente.nome_fantasia
        razao_social      : $db.Cliente.razao_social
        contato           : $db.Cliente.contato
        cpf               : $db.Cliente.cpf
        cnpj              : $db.Cliente.cnpj
        inscricao_estadual: $db.Cliente.inscricao_estadual
      }
    
      return = {
        type  : "list"
        paging: {page: $input.page, per_page: $input.per_page}
      }
    
      output = [
        "itemsReceived"
        "curPage"
        "nextPage"
        "prevPage"
        "offset"
        "itemsTotal"
        "pageTotal"
        "items.id"
        "items.created_at"
        "items.cod_orca"
        "items.cliente_id"
        "items.frtB2B"
        "items.frtB2C"
        "items.validade"
        "items.user_id"
        "items.margem"
        "items.cst_tot"
        "items.luc_tot"
        "items.vnd_tot"
        "items.vnd_B2B_tot"
        "items.vnd_B2B_B2C_tot"
        "items.desconto"
        "items.eh_pedido"
        "items.data_envio"
        "items.data_aprovacao"
        "items.total_itens"
        "items.mao_de_obra"
        "items.nome_fantasia"
        "items.razao_social"
        "items.contato"
        "items.cpf"
        "items.cnpj"
        "items.iscricao_estadual"
        "items.nome"
        "items.doc"
        "items.tipo_doc"
      ]
    } as $orca
  
    !debug.stop {
      value = $orca
    }
  
    !api.lambda {
      code = """
        let orca = $var.orca; // Pega o objeto completo da paginação
        let busca = $input.busca;
        
        // Executa o filtro no array de items
        let itemsFiltrados = filtrarOrcamentos(orca.items || [], busca);
        
        // Retorna o objeto mantendo o cabeçalho original e atualizando os itens + quantidade recebida
        return {
          ...orca,
          itemsReceived: itemsFiltrados.length, // Atualiza a contagem da página atual
          items: itemsFiltrados
        };
        
        
        function filtrarOrcamentos(dados, busca) {
          if (!busca || typeof busca !== 'string' || !busca.trim()) {
            return dados;
          }
        
          const normalizar = (texto) => {
            if (texto === null || texto === undefined) return '';
            return String(texto)
              .normalize('NFD')
              .replace(/[\u0300-\u036f]/g, '')
              .toLowerCase()
              .trim();
          };
        
          const apenasNumeros = (texto) => String(texto || '').replace(/\D/g, '');
        
          const termoBusca = normalizar(busca);
          const termoNumerico = apenasNumeros(busca);
        
          const camposTexto = [
            'cod_orca',
            'nome_fantasia',
            'razao_social',
            'contato',
            'cpf',
            'cnpj',
            'inscricao_estadual'
          ];
        
          return dados.filter((item) => {
            if (item.cliente_id && String(item.cliente_id) === termoBusca) {
              return true;
            }
        
            if (termoNumerico.length > 0) {
              const cnpjLimpo = apenasNumeros(item.cnpj);
              const cpfLimpo = apenasNumeros(item.cpf);
              const ieLimpa = apenasNumeros(item.inscricao_estadual);
        
              if (
                (cnpjLimpo && cnpjLimpo.includes(termoNumerico)) ||
                (cpfLimpo && cpfLimpo.includes(termoNumerico)) ||
                (ieLimpa && ieLimpa.includes(termoNumerico))
              ) {
                return true;
              }
            }
        
            return camposTexto.some((campo) => {
              const valorCampo = normalizar(item[campo]);
              return valorCampo.includes(termoBusca);
            });
          });
        }
        """
      timeout = 10
    } as $orca
  }

  response = $orca
  guid = "tc_K3okmRrY3gyQDmobPk85OS7c"
}