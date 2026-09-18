function Texto_Envio_WhatsApp {
  input {
    int orca_id? {
      table = "Orca"
    }
  
    // Se vou faturar para o cliente ou não
    bool bfatura?
  }

  stack {
    function.run Orcamento_Detalhes_v2 {
      input = {orca_id: $input.orca_id}
    } as $func_1
  
    // Detalhar as condições de pagamento
    api.lambda {
      code = """
        
        const valorVenda = $var.func_1.tot_vnd_total_b2b_b2c;
        const valorCusto = $var.func_1.tot_cst_total;
        const bfaturar = $input.bfatura;
        
        const entradaPrazo = 5; // 5 dias para a primeira parcela
            const intervaloParcelas = 30; // Intervalo de 30 dias entre as parcelas
        
            // Regra para o Pix (2 parcelas fixas)
            const primeiraParcelaPix = valorVenda / 2;
            const segundaParcelaPix = valorVenda / 2;
            const pixString = `Pix (2x) R$ ${primeiraParcelaPix.toFixed(2)} 1ª. em ${entradaPrazo}dd do pedido e 2ª em ${entradaPrazo + intervaloParcelas}dd`;
        
            // Regra para o boleto bancário
            const metadeCusto = valorCusto / 2; // Divide o custo por 2
            const numeroParcelas = Math.floor(valorVenda / metadeCusto); // Número de parcelas, arredondado para baixo
            const valorParcelas = valorVenda / numeroParcelas; // Valor das parcelas
        
            let prazos = `1ª. em ${entradaPrazo}dd do pedido e demais em `;
            for (let i = 1; i < numeroParcelas; i++) {
                const prazoAtual = entradaPrazo + i * intervaloParcelas;
                prazos += `${prazoAtual}dd`;
                if (i < numeroParcelas - 1) {
                    prazos += '/'; // Adiciona a barra entre os prazos
                }
            }
        
            const boletoString = `boleto (${numeroParcelas}x) R$ ${valorParcelas.toFixed(2)} ${prazos}`;
        
            // Cálculo de parcelas para faturamento, caso `bfaturar` seja true
            let faturadoString = '';
            if (bfaturar) {
                const numeroParcelasFaturamento = Math.floor(valorVenda / valorCusto); // Calcula o número de parcelas para faturamento
                const valorParcelasFaturamento = valorVenda / numeroParcelasFaturamento; // Valor das parcelas de faturamento
                
                // Gera prazos para as parcelas de faturamento, começando com 20 dias e somando 30 para cada
                let prazosFaturamento = 'em ';
                for (let i = 0; i < numeroParcelasFaturamento; i++) {
                    const prazoFaturamento = 20 + i * 30;
                    prazosFaturamento += `${prazoFaturamento}dd`;
                    if (i < numeroParcelasFaturamento - 1) {
                        prazosFaturamento += ', '; // Adiciona a vírgula entre os prazos
                    }
                }
        
                faturadoString = `\nFaturado: (${numeroParcelasFaturamento}x) R$ ${valorParcelasFaturamento.toFixed(2)} ${prazosFaturamento}`;
            }
        
            // Retorno com as opções de pagamento e, se `bfaturar` for true, com a linha de faturamento
            return `${pixString}\n${boletoString}${faturadoString}`;
        """
      timeout = 10
    } as $cond_pgto
  
    !debug.stop {
      value = $func_1.User_1.google_oauth
    }
  
    var $TextoWhats {
      value = {}
        |set:"contato":$func_1.ORCA_1._cliente.contato
        |set:"empresa":$func_1.ORCA_1._cliente.nome_fantasia
        |set:"objetivo":"Segue o orçamento: "
        |set:"orcamento":$func_1.ORCA_1.cod_orca
        |set:"total_parcial":($func_1.tot_vnd_total_b2b
          |add:$func_1.desconto
          |number_format:2:",":"."
        )
        |set:"frete":($func_1.frete_B2C|number_format:2:",":".")
        |set:"desconto":($func_1.desconto|number_format:2:",":".")
        |set:"total":($func_1.tot_vnd_total_b2b_b2c|number_format:2:",":".")
        |set:"cli":$func_1.ORCA_1._cliente
    }
  
    var $produtos {
      value = []
    }
  
    foreach ($func_1.itemS) {
      each as $item {
        !debug.stop {
          value = $item.larg
        }
      
        var.update $produtos {
          value = $produtos
            |push:(""
              |set:"Desc":$item.Descricao
              |set:"Obs":$item.descricao
              |set:"qtd":$item.qtd
              |set:"valorunit":($item.vlr_vnd_c_taxas_unit_b2b|number_format:2:",":".")
              |set:"valor":($item.vlr_vnd_c_taxas_tot_b2b|number_format:2:",":".")
              |set:"largura":($item.larg|multiply:(100|round:0))
              |set:"comprimento":($item.comp|multiply:(100|round:0))
            )
        }
      
        !var.update $produtos {
          value = $produtos
            |push:(""
              |set:"Desc":$item.Descricao
              |set:"qtd":("Qtd:"|concat:$item.qtd:" ")
              |set:"valor":("Valor:"
                |concat:($item.vlr_vnd_c_taxas_tot_b2b|number_format:2:",":"."):" "
              )
            )
        }
      }
    }
  
    var $whatsapp {
      value = '""'
    }
  
    foreach ($func_1.ORCA_1._cliente._telefone_cliente_of_cliente) {
      each as $item {
        conditional {
          if ($item.tipo_telefone_id == "1" || $item.tipo_telefone_id == 6) {
            var.update $whatsapp {
              value = $item.telefone
            }
          
            break
          }
        }
      
        !debug.stop {
          value = $whatsapp
        }
      }
    }
  }

  response = {
    produtos  : $produtos
    TextoWhats: $TextoWhats
    func_1    : $func_1
    whatsapp  : $whatsapp
    condicoes : $cond_pgto
  }

  guid = "GT6sUewpf0l7T8cjDufqerlHKEY"
}