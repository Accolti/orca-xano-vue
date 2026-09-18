// Retorna as taxas ativas do nubank
function f_taxas_banco {
  input {
    decimal valor_cobrado?
    bool repassar_para_cliente?=true
    int provedor_id? {
      table = "Provedor"
    }
  }

  stack {
    db.query Taxa_Banco {
      join = {
        Provedor: {
          table: "Provedor"
          where: $db.Taxa_Banco.provedor_id == $db.Provedor.id
        }
      }
    
      where = $db.Taxa_Banco.ativo == true && $db.Taxa_Banco.provedor_id == $input.provedor_id
      sort = {Taxa_Nubank.parcelas: "asc"}
      eval = {provedor: $db.Provedor.nome}
      return = {type: "list"}
      output = ["parcelas", "cc_taxa", "provedor"]
    } as $Taxa_Banco
  
    api.lambda {
      code = """
        /**
         * Calcula a tabela de parcelamento dinâmica
         * @param {Array} tabelaTaxas - Array de objetos [{ parcelas, cc_taxa }]
         * @param {number} valorBase - O valor do seu produto/serviço (ex: 2840.00)
         * @param {boolean} repassarTaxas - true para o cliente pagar a taxa, false para você pagar
         */
        
        const tabelaTaxas = $var.Taxa_Banco;
        const valorBase = $input.valor_cobrado || 0;
        const repassarTaxas = $input.repassar_para_cliente;
        
        return calcularTabelaParcelamento(tabelaTaxas,valorBase,repassarTaxas)
        
        function calcularTabelaParcelamento(tabelaTaxas, valorBase, repassarTaxas = true) {
          return tabelaTaxas.map(item => {
            const parcelas = item.parcelas;
            const taxaDecimal = item.cc_taxa / 100;
            
            let valorTotalCliente = 0;
            let valorLiquidoVoceRecebe = 0;
        
            if (repassarTaxas) {
              // GROSS-UP: Cliente assume a taxa
              valorTotalCliente = valorBase / (1 - taxaDecimal);
              valorLiquidoVoceRecebe = valorBase;
            } else {
              // DIRETO: Você assume a taxa
              valorTotalCliente = valorBase;
              valorLiquidoVoceRecebe = valorBase * (1 - taxaDecimal);
            }
        
            const valorParcela = valorTotalCliente / parcelas;
            const custoTaxa = valorTotalCliente - valorLiquidoVoceRecebe;
        
            return {
              parcelas: parcelas,
              taxaPercentual: `${item.cc_taxa}%`,
              clientePagaTotal: parseFloat(valorTotalCliente.toFixed(2)),
              valorParcela: parseFloat(valorParcela.toFixed(2)),
              voceRecebeLiquido: parseFloat(valorLiquidoVoceRecebe.toFixed(2)),
              custoTaxa: parseFloat(custoTaxa.toFixed(2))
            };
          });
        }
        """
      timeout = 10
    } as $retorno
  }

  response = $retorno
  guid = "t3izFWf-Ao2w4HOf3RSTyAKrTsg"
}