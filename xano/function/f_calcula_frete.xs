// Calcula o frete B2B (regra Kapazi) a partir do valor total de compra.
//
// OTIMIZAÇÃO: aceita `frt_b2b` já resolvido pelo caller. Quando `frt_b2b_informado = true`,
// pula as consultas a User/Perfil (evita leituras duplicadas em requests que já resolveram
// a config efetiva). Sem o flag, mantém o comportamento antigo (resolve pelo usuário logado).
function fCalculaFrete {
  input {
    // Valor total de custo 
    decimal valor_total_compra?
  
    // Valor efetivo de frtB2B já resolvido pelo caller (opcional)
    decimal frt_b2b?
  
    // true = usar `frt_b2b` como valor final (não reconsultar User/Perfil)
    bool frt_b2b_informado?
  }

  stack {
    var $frete_b2b {
      value = $input.frt_b2b
    }
  
    conditional {
      if ($input.frt_b2b_informado != true) {
        db.get User {
          field_name = "id"
          field_value = $auth.id
        } as $User1
      
        // Config efetiva (filhos herdam do topo da empresa)
      
        function.run f_perfil_efetivo {
          input = {user_id: $auth.id}
        } as $UsEfet
      
        var.update $frete_b2b {
          value = $User1.frtB2B
        }
      
        conditional {
          if (($frete_b2b == null) || ($frete_b2b == 0)) {
            var.update $frete_b2b {
              value = $UsEfet.frtB2B|first_notnull:0
            }
          }
        }
      }
    }
  
    api.lambda {
      code = """
        
        let valorPedido = $input.valor_total_compra;
        let minimo = $var.frete_b2b || 50;
        
        return calcularFrete(valorPedido,minimo);
        
        function calcularFrete(valorPedido, minimo) {
          // Pedidos a partir de R$ 1.000,00: Frete grátis
          if (valorPedido >= 1000) {
            return 0;
          } 
          // Pedidos a partir de R$ 300,00 até R$ 999,99: 10% do valor do pedido
          else if (valorPedido >= 300) {
            return valorPedido * 0.10;
          } 
          // Pedidos abaixo de R$ 300,00: Valor fixo de R$ 52,00 (cotação estimada)
          else {
            if (valorPedido <= 0){
              return 0;}
            else{
                 return minimo;
              }
            
           
          }
        }
        """
      timeout = 10
    } as $valor_frete
  }

  response = $valor_frete
  tags = ["novo-sis"]
  guid = "A0GDWkmUKPeXrMK7OBc-dyPSomk"
}
