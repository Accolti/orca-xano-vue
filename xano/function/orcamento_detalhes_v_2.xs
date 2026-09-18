// novo-sis: versão nova do Orcamento_Detalhes (substitui a legada quebrada).
// Consome Orcamento_Recalcular_Totais (motor novo) e devolve o contrato que
// os consumidores (WhatsApp, Pedido) esperam: ORCA_1 (com _cliente/User_1),
// itemS com Descricao + vlr_vnd_c_taxas_*, e os totais consolidados.
function Orcamento_Detalhes_v2 {
  input {
    int orca_id? {
      table = "Orca"
    }
  }

  stack {
    function.run Orcamento_Recalcular_Totais {
      input = {orca_id: $input.orca_id}
    } as $func_1
  
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
      addon = [
        {
          name : "Cliente"
          input: {Cliente_id: $output.cliente_id}
          addon: [
            {
              name : "Endereco_Cliente"
              input: {cliente_id: $output.id}
              as   : "_endereco_cliente"
            }
            {
              name  : "Telefone_Cliente_of_Cliente"
              output: [
                "id"
                "created_at"
                "cliente_id"
                "tipo_telefone_id"
                "telefone"
                "descricao"
              ]
              input : {cliente_id: $output.id}
              as    : "_telefone_cliente_of_cliente"
            }
          ]
          as   : "_cliente"
        }
      ]
    } as $Orca_1
  
    db.get User {
      field_name = "id"
      field_value = $Orca_1.user_id
    } as $User_1
  
    api.lambda {
      code = """
        const recalc = $var.func_1 || {};
        const totais = recalc.totais || {};
        const itens = (recalc.itemS || []).map(item => {
          const qtd = Number(item.qtd) || 1;
          const vndB2B = Number(item.vlr_vnd_unit_b2b) || Number(item.vlr_vnd_unit) || 0;
          return {
            ...item,
            vlr_vnd_c_taxas_unit_b2b: vndB2B,
            vlr_vnd_c_taxas_tot_b2b: vndB2B * qtd
          };
        });
        
        const totCst = Number(totais.cst_tot) || 0;
        const totVnd = Number(totais.vnd_tot) || 0;
        const freteB2b = Number(totais.frete_b2b_total) || 0;
        const qtdItens = itens.length || 0;
        
        return {
          tot_vnd_total       : totVnd,
          tot_vnd_total_b2b   : Number(totais.vnd_B2B_tot) || totVnd,
          tot_vnd_total_b2b_b2c: Number(totais.vnd_B2B_B2C_tot) || totVnd,
          tot_cst_total       : totCst,
          margem_tot          : Number(totais.margem) || 0,
          desconto            : Number(totais.desconto) || 0,
          frete_B2C           : Number(totais.frtB2C) || 0,
          valor_medio_b2b     : qtdItens > 0 ? freteB2b / qtdItens : 0,
          total_itens         : qtdItens,
          itemS               : itens
        };
        """
      timeout = 10
    } as $Totais
  }

  response = {
    ORCA_1               : $Orca_1
    User_1               : $User_1
    itemS                : $Totais.itemS
    tot_vnd_total        : $Totais.tot_vnd_total
    tot_vnd_total_b2b    : $Totais.tot_vnd_total_b2b
    tot_vnd_total_b2b_b2c: $Totais.tot_vnd_total_b2b_b2c
    tot_cst_total        : $Totais.tot_cst_total
    margem_tot           : $Totais.margem_tot
    desconto             : $Totais.desconto
    frete_B2C            : $Totais.frete_B2C
    valor_medio_b2b      : $Totais.valor_medio_b2b
    total_itens          : $Totais.total_itens
    prazo_entrega        : "Prazo não definido"
  }

  tags = ["orcamento", "novo-sis"]
  guid = "Orcamento-Detalhes-v2-novo-sis"
}