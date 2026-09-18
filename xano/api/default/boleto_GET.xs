// Query all Boleto records
query boleto verb=GET {
  api_group = "Default"
  auth = "User"

  input {
  }

  stack {
    db.query Boleto {
      where = $db.Boleto.user_id == $auth.id
      sort = {boleto.vencimento: "asc"}
      eval = {status: $db.boleto.id, nmCliente: $db.boleto.obs}
      return = {type: "list"}
      output = [
        "id"
        "created_at"
        "vencimento"
        "pagamento"
        "valor"
        "obs"
        "pedido_id"
        "user_id"
        "status"
        "nmCliente"
      ]
    
      addon = [
        {
          name : "Pedido"
          input: {Pedido_id: $output.pedido_id}
          addon: [
            {
              name : "Cliente"
              input: {Cliente_id: $output.cliente_id}
              as   : "_cliente"
            }
          ]
          as   : "_pedido"
        }
      ]
    } as $boleto
  
    !debug.stop {
      value = $boleto
    }
  
    function.run fBoleto_A_Vencer {
      input = {
        user_id  : $item.user_id
        Tipo     : '"contar"'
        qtdDias  : 5
        boleto_id: $item.id
      }
    } as $func_1
  
    !foreach ($boleto) {
      each as $item {
        !debug.stop {
          value = $func_1
        }
      
        conditional {
          if ($func_1 == 1) {
            var.update $item.status {
              value = "A VENCER"
            }
          }
        }
      
        function.run fBoleto_Vencido {
          input = {
            user_id  : $item.user_id
            Tipo     : '"contar"'
            boleto_id: $item.id
          }
        } as $func_2
      
        conditional {
          if ($func_2 == 1) {
            var.update $item.status {
              value = "VENCIDO"
            }
          }
        }
      
        var.update $item.nmCliente {
          value = $item._pedido._cliente.nome_fantasia
        }
      
        !debug.stop {
          value = $func_2
        }
      }
    }
  
    api.lambda {
      code = """
        function adicionarStatusBoleto(arrayBoleto, diasAviso = 7) {
            const hoje = new Date();
            hoje.setHours(0, 0, 0, 0);
            
            return arrayBoleto.map(boleto => {
                const vencimento = new Date(boleto.vencimento);
                vencimento.setHours(0, 0, 0, 0);
                
                const pagamento = boleto.pagamento ? new Date(boleto.pagamento) : null;
                if (pagamento) {
                    pagamento.setHours(0, 0, 0, 0);
                }
                
                // Calcula a data a partir da qual começa o aviso
                const dataAviso = new Date(vencimento);
                dataAviso.setDate(dataAviso.getDate() - diasAviso);
                
                let statusText = '';
                
                // Se foi pago, status é "Pago"
                if (pagamento) {
                    statusText = 'Pago';
                }
                // Se vencimento é no futuro
                else if (vencimento > hoje) {
                    // Se está dentro do período de aviso
                    if (hoje >= dataAviso) {
                        statusText = 'A vencer';
                    }
                    // Senão está em dia
                    else {
                        statusText = 'Em dia';
                    }
                }
                // Se vencimento é no passado ou igual a hoje (e não foi pago)
                else {
                    statusText = 'Vencido';
                }
                
                return {
                    ...boleto,
                    nmCliente: boleto._pedido._cliente.nome_fantasia,
                    statusDescricao: statusText
                };
            });
        }
        
        
        return adicionarStatusBoleto($var.boleto,10)
        """
      timeout = 10
    } as $boleto
  
    conditional {
      if ($func_3 == 1) {
        var.update $item.status {
          value = "PAGO"
        }
      }
    }
  
    function.run fBoleto_Pago {
      input = {
        user_id  : $item.user_id
        Tipo     : '"contar"'
        boleto_id: $item.id
      }
    } as $func_3
  }

  response = $boleto
  guid = "qK7GRy0dAo38T5iMR4Hs-_kMKUc"
}