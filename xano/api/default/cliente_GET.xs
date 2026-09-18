// Query all cliente records
query cliente verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Cliente {
      where = $db.Cliente.user_id == $auth.id
      eval = {
        nome   : $db.cliente.razao_social|coalesce:$db.cliente.nome_fantasia
        qtd_orc: $db.cliente.observacao
      }
    
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "razao_social"
        "nome_fantasia"
        "contato"
        "cpf"
        "nome_cpf"
        "cnpj"
        "inscricao_estadual"
        "e-mail"
        "contribui_icms"
        "isento"
        "observacao"
        "user_id"
        "beneficio_fiscal_id"
        "mercado_id"
        "ramo_id"
        "regime_id"
        "nome"
      ]
    
      addon = [
        {
          name : "Endereco_Cliente"
          input: {cliente_id: $output.id}
          as   : "_endereco"
        }
        {
          name  : "Telefone"
          output: ["id", "created_at", "telefone", "cliente_id", "tipo_telefone_id"]
          input : {Telefone_Cliente_id: $output.id}
          as    : "_telefone"
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
  guid = "P0sqjYFR7gjQNkSoCaNzf9qKNag"
}