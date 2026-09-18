// Delete cliente record.
query "cliente/{cliente_id}" verb=DELETE {
  api_group = "Default"
  auth = "User"

  input {
    int cliente_id? filters=min:1
  }

  stack {
    function.run fQtd_Orca_por_cliente {
      input = {cliente_id: $input.cliente_id}
    } as $qtd
  
    precondition ($qtd <= 0) {
      error_type = "badrequest"
      error = "Este cliente não pode ser excluido pois já tem orçamentos"
      payload = $qtd|concat:"orçamento(s)":" "
    }
  
    db.transaction {
      stack {
        db.del Cliente {
          field_name = "id"
          field_value = $input.cliente_id
        }
      
        db.query Endereco_Cliente {
          where = $db.Endereco_Cliente.id == $input.cliente_id
          return = {type: "list"}
        } as $Endereco_Cliente1
      
        foreach ($Endereco_Cliente1) {
          each as $endereco {
            db.del Endereco_Cliente {
              field_name = "id"
              field_value = $endereco.id
            }
          }
        }
      
        db.query Telefone_Cliente {
          where = $db.Telefone_Cliente.id == $input.cliente_id
          return = {type: "list"}
        } as $Telefone_Cliente1
      
        foreach ($Telefone_Cliente1) {
          each as $telefone {
            db.del Telefone_Cliente {
              field_name = "id"
              field_value = $telefone.id
            }
          }
        }
      }
    }
  }

  response = $cliente
  guid = "17sy75bfE14vM0cauxpg9VWEy7k"
}