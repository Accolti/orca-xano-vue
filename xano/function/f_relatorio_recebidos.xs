function f_relatorio_recebidos {
  input {
    date? dt_ini?
    date? dt_fin?
    int user_id? {
      table = "User"
    }
  }

  stack {
    db.query Pedido {
      join = {
        ControlePedido: {
          table: "ControlePedido"
          type : "left"
          where: $db.ControlePedido.pedido_id == $db.Pedido.id
        }
      }
    
      where = ($db.Pedido.created_at|between:$input.dt_ini:$input.dt_fin) == true && $db.Pedido.user_id == $input.user_id
      eval = {
        controle_id : $db.ControlePedido.id
        dataPrevisao: $db.ControlePedido.dataPrevisao
        dataChegada : $db.ControlePedido.dataChegada
      }
    
      return = {type: "list"}
      addon = [
        {
          name : "Boleto_of_Pedido"
          input: {pedido_id: $output.id}
          as   : "_boleto_of_pedido"
        }
      ]
    } as $Pedido1
  
    db.query Forma_Pagamento {
      return = {type: "list"}
    } as $Forma_Pgto
  
    api.lambda {
      code = """
        const fpgto = $var.Forma_Pgto;
        const ped = $var.Pedido1;
        
        const formasPgto = {};
        fpgto.forEach(f => {
          formasPgto[f.id] = f.tipo;
        });
        
        const hoje = new Date();
        
        let somaValorFinal = 0;
        let somaCustoTotal = 0;
        let somaLucro = 0;
        
        const pedidos = ped.map(ped => {
          const lucro = ped.vlr_vnd_tot_b2b - ped.vlr_cst_tot;
        
          somaValorFinal += ped.vlr_vnd_tot_b2b_b2c;
          somaCustoTotal += ped.vlr_cst_tot;
          somaLucro += lucro;
        
          let parcelas = [];
          if (ped._boleto_of_pedido && ped._boleto_of_pedido.length > 0) {
            parcelas = ped._boleto_of_pedido.map(parc => {
              let status = "em aberto";
              if (parc.pagamento) {
                status = "pago";
              } else {
                const dtVenc = new Date(parc.vencimento);
                if (dtVenc < hoje) {
                  status = "atrasado";
                }
              }
              return {
                id: parc.id,
                vencimento: parc.vencimento,
                pagamento: parc.pagamento,
                valor: parc.valor,
                forma_pagamento: formasPgto[parc.forma_pagamento_id] || "Desconhecida",
                status
              };
            });
          } else {
            // Caso não tenha boletos, considerar pagamento único e pago
            parcelas = [{
              id: null,
              vencimento: ped.dataChegada || ped.dataPrevisao,
              pagamento: ped.dataChegada || ped.dataPrevisao,
              valor: ped.vlr_vnd_tot_b2b_b2c,
              forma_pagamento: "Pagamento Único",
              status: "pago"
            }];
          }
        
          return {
            id: ped.id,
            numero_pedido: ped.num_ped,
            codigo_orcamento: ped.cod_orca,
            cliente_id: ped.cliente_id,
            freteB2B: ped.frtB2B,
            freteB2C: ped.frtB2C,
            valor_final: ped.vlr_vnd_tot_b2b_b2c,
            custo_total: ped.vlr_cst_tot,
            lucro,
            data_previsao: ped.dataPrevisao,
            data_chegada: ped.dataChegada,
            parcelas
          };
        });
        
        const margemTotal = somaValorFinal > 0 ? (somaLucro / somaValorFinal) * 100 : 0;
        
        const relatorio = {
          pedidos,
          totais: {
            soma_valor_final: somaValorFinal,
            soma_custo_total: somaCustoTotal,
            soma_lucro: somaLucro,
            margem_total: margemTotal
          }
        };
        
        return relatorio;
        """
      timeout = 10
    } as $Relatorio
  }

  response = {rela: $Relatorio}
  tags = ["pedidos"]
  guid = "oZqDkGU6pAZ20cgybH_ceOSpAWQ"
}