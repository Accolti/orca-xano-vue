// Query all cliente records
query cliente_2 verb=GET {
  api_group = "Default"
  auth = "User"

  input {
    text page? filters=trim
    text offset? filters=trim
    text perPage? filters=trim
  }

  stack {
    db.query Cliente {
      where = $db.Cliente.user_id == $auth.id
      eval = {
        nome   : $db.cliente.razao_social|coalesce:$db.cliente.nome_fantasia
        qtd_orc: $db.cliente.observacao
      }
    
      return = {
        type  : "list"
        paging: {
          page    : $input.page
          per_page: $input.perPage
          totals  : true
          offset  : $input.offset
        }
      }
    
      output = [
        "itemsReceived"
        "curPage"
        "nextPage"
        "prevPage"
        "offset"
        "perPage"
        "itemsTotal"
        "pageTotal"
        "items.id"
        "items.razao_social"
        "items.nome_fantasia"
        "items.contato"
        "items.cpf"
        "items.nome_cpf"
        "items.cnpj"
        "items.inscricao_estadual"
        "items.e-mail"
        "items.contribui_icms"
        "items.isento"
        "items.observacao"
        "items.user_id"
        "items.beneficio_fiscal_id"
        "items.mercado_id"
        "items.ramo_id"
        "items.regime_id"
        "items.created_at"
        "items.nome"
      ]
    
      addon = [
        {
          name : "Endereco_Cliente"
          input: {cliente_id: $output.id}
          as   : "items._endereco"
        }
        {
          name  : "Telefone"
          output: ["id", "created_at", "telefone", "cliente_id", "tipo_telefone_id"]
          input : {Telefone_Cliente_id: $output.id}
          as    : "items._telefone"
        }
      ]
    } as $cliente
  
    !foreach ($cliente) {
      each as $item {
        !debug.stop {
          value = $item.id
        }
      
        function.run fQtd_Orca_por_cliente {
          input = {cliente_id: $item.id}
        } as $func_1
      
        var.update $item.qtd_orc {
          value = $func_1
        }
      }
    }
  }

  response = $cliente
  guid = "jjvV7EJZXDm-p3_RyR1HZmR-9zo"
}