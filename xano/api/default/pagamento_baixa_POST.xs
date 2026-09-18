// novo-sis: baixa (marca pago) ou estorna a baixa de uma parcela financeira.
// Ao pagar, se o pedido (eh_pedido) do vendedor ficar 100% pago, lança a comissão:
//  - Fase A.2 (Master + faixas configuradas da empresa): ponta + override do Master,
//    base = venda (vnd_tot), faixa pelo markup efetivo.
//  - Fase A (sem faixas/Master): 1 lançamento fixo do vendedor sobre lucro real.
query pagamento_baixa verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int boleto_id? {
      table = "Boleto"
    }
  
    date? pagamento?
    bool estornar?
  }

  stack {
    // Reforço: bloqueia quem foi desativado (o próprio ou um "pai") após o login
    function.run f_ativo_efetivo {
      input = {user_id: $auth.id}
    } as $ativoEfetivo
  
    precondition ($ativoEfetivo) {
      error_type = "accessdenied"
      error = "Conta inativa. Fale com o administrador."
    }
  
    db.get Boleto {
      field_name = "id"
      field_value = $input.boleto_id
    } as $Boleto_0
  
    precondition ($Boleto_0 != null) {
      error_type = "notfound"
      error = "Parcela não encontrada."
    }
  
    precondition ($Boleto_0.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "Acesso negado."
    }
  
    conditional {
      if ($input.estornar) {
        db.edit Boleto {
          field_name = "id"
          field_value = $input.boleto_id
          enforce_hidden_fields = false
          data = {pagamento: null}
        } as $Boleto_1
      }
    
      else {
        var $data_pagamento {
          value = $input.pagamento
        }
      
        conditional {
          if ($data_pagamento == null) {
            var.update $data_pagamento {
              value = "today"
            }
          }
        }
      
        db.edit Boleto {
          field_name = "id"
          field_value = $input.boleto_id
          enforce_hidden_fields = false
          data = {pagamento: $data_pagamento}
        } as $Boleto_1
      }
    }
  
    // ---- Comissões (Fase A / A.2): lança quando o pedido do vendedor fica 100% pago ----
    conditional {
      if (!$input.estornar) {
        db.get Orca {
          field_name = "id"
          field_value = $Boleto_0.orca_id
          output = [
            "id"
            "user_id"
            "eh_pedido"
            "vnd_tot"
            "cst_tot"
            "markup_efetivo"
            "luc_tot"
            "frtB2B"
          ]
        } as $OrcaC
      
        conditional {
          if (($OrcaC != null) && $OrcaC.eh_pedido) {
            db.get User {
              field_name = "id"
              field_value = $OrcaC.user_id
              output = ["id", "role", "vendedor_pai_id", "percentual_comissao"]
            } as $Dono
          
            var $Master {
              value = null
            }
          
            var $Empresa {
              value = null
            }
          
            var $faixasEmp {
              value = []
            }
          
            conditional {
              if (($Dono.role == "vendedor") && ($Dono.vendedor_pai_id != null) && ($Dono.vendedor_pai_id > 0)) {
                db.get User {
                  field_name = "id"
                  field_value = $Dono.vendedor_pai_id
                  output = ["id", "role", "vendedor_pai_id", "percentual_comissao"]
                } as $MasterRaw
              
                var.update $Master {
                  value = $MasterRaw
                }
              }
            }
          
            conditional {
              if (($Master != null) && ($Master.role == "vendedor_master") && ($Master.vendedor_pai_id != null) && ($Master.vendedor_pai_id > 0)) {
                db.get User {
                  field_name = "id"
                  field_value = $Master.vendedor_pai_id
                  output = ["id", "role"]
                } as $EmpresaRaw
              
                var.update $Empresa {
                  value = $EmpresaRaw
                }
              
                db.query Faixa_Comissao {
                  where = $db.Faixa_Comissao.user_id == $EmpresaRaw.id && $db.Faixa_Comissao.ativo == true
                  sort = {faixa_min: "asc"}
                  return = {type: "list"}
                } as $faixasRaw
              
                var.update $faixasEmp {
                  value = $faixasRaw
                }
              }
            }
          
            // Master vendendo: a "empresa" é o pai dele (admin) e as faixas da empresa valem
            conditional {
              if (($Dono.role == "vendedor_master") && ($Dono.vendedor_pai_id != null) && ($Dono.vendedor_pai_id > 0)) {
                db.get User {
                  field_name = "id"
                  field_value = $Dono.vendedor_pai_id
                  output = ["id", "role"]
                } as $EmpresaRaw2
              
                var.update $Empresa {
                  value = $EmpresaRaw2
                }
              
                db.query Faixa_Comissao {
                  where = $db.Faixa_Comissao.user_id == $EmpresaRaw2.id && $db.Faixa_Comissao.ativo == true
                  sort = {faixa_min: "asc"}
                  return = {type: "list"}
                } as $faixasRaw2
              
                var.update $faixasEmp {
                  value = $faixasRaw2
                }
              }
            }
          
            db.query Boleto {
              where = $db.Boleto.orca_id == $OrcaC.id
              return = {type: "list"}
              output = ["pagamento"]
            } as $parcelasOrca
          
            db.query item {
              where = $db.item.orca_id == $OrcaC.id
              return = {type: "list"}
              output = ["qtd", "vlr_cst_nota_unit"]
            } as $itensComissao
          
            db.query ControlePedido {
              where = $db.ControlePedido.orca_id == $OrcaC.id
              return = {type: "single"}
              output = ["desconto_kapazi_perc", "freteB2BReal"]
            } as $controleComissao
          
            db.query Desconto_Kapazi_Log {
              where = $db.Desconto_Kapazi_Log.orca_id == $OrcaC.id
              sort = {created_at: "desc"}
              return = {type: "list"}
              output = ["desconto_novo"]
            } as $logsComissao
          
            api.lambda {
              code = """
                const arred = (n) => Number(Number(n || 0).toFixed(2));
                const parcelas = $var.parcelasOrca || [];
                const pagoCompleto = parcelas.length > 0 && parcelas.every((p) => p.pagamento !== null && p.pagamento !== undefined && String(p.pagamento || '').trim() !== '');
                if (!pagoCompleto) return { registros: [] };
                
                const orca = $var.OrcaC || {};
                const dono = $var.Dono || {};
                const master = $var.Master || null;
                const empresa = $var.Empresa || null;
                const faixas = $var.faixasEmp || [];
                const vnd = Number(orca.vnd_tot) || 0;
                const registros = [];
                const mk = (user_id, papel, percentual, base) => {
                  const p = Number(percentual) || 0;
                  if (p <= 0 || base <= 0) return;
                  registros.push({
                    user_id: Number(user_id) || 0,
                    tipo: papel,
                    percentual: p,
                    base: arred(base),
                    valor: arred((base * p) / 100)
                  });
                };
                
                const temMaster = master && master.role === 'vendedor_master';
                const temEmpresa = empresa && (empresa.role === 'admin' || empresa.role === 'admin_geral');
                const donoRole = dono.role || '';
                
                const acharTotalFaixa = () => {
                  const markupEf = Number(orca.markup_efetivo);
                  const ef = !isNaN(markupEf) && markupEf > 0 ? markupEf : (Number(orca.cst_tot) > 0 ? ((vnd / Number(orca.cst_tot)) - 1) * 100 : 0);
                  for (const f of faixas) {
                    const min = Number(f.faixa_min);
                    const max = f.faixa_max != null ? Number(f.faixa_max) : null;
                    if (ef >= min && (max == null || ef <= max)) return Number(f.comissao_total_perc) || 0;
                  }
                  return 0;
                };
                
                if (temMaster && temEmpresa && faixas.length > 0) {
                  // A.2: ponta recebe o % dele; Master recebe o override (resto da faixa)
                  const total = acharTotalFaixa();
                  let pctPonta = Number(dono.percentual_comissao) || 0;
                  if (pctPonta > total) pctPonta = total;
                  const override = Math.max(0, total - pctPonta);
                  mk(dono.id, 'vendedor', pctPonta, vnd);
                  if (override > 0) mk(master.id, 'override', override, vnd);
                } else if (donoRole === 'vendedor_master' && temEmpresa && faixas.length > 0) {
                  // Master vendendo: ele leva o total da faixa (não há ponta/override)
                  mk(dono.id, 'override', acharTotalFaixa(), vnd);
                } else {
                  // Fallback Fase A: % fixo do vendedor sobre o lucro real
                  const itens = $var.itensComissao || [];
                  const custoKapazi = itens.reduce((s, i) => s + ((Number(i.vlr_cst_nota_unit) || 0) * (Number(i.qtd) || 1)), 0);
                  const controle = $var.controleComissao || {};
                  const logs = $var.logsComissao || [];
                  const percLog = logs.length && logs[0].desconto_novo != null ? Number(logs[0].desconto_novo) : null;
                  const perc = (percLog != null ? percLog : Number(controle.desconto_kapazi_perc) || 0) || 0;
                  const descontoKapazi = custoKapazi * (perc / 100);
                  const frtB2B = Number(orca.frtB2B) || 0;
                  const freteRealRaw = controle.freteB2BReal != null ? Number(controle.freteB2BReal) : 0;
                  const freteEfetivo = freteRealRaw > 0 ? freteRealRaw : frtB2B;
                  const lucroReal = (Number(orca.luc_tot) || 0) + descontoKapazi + (frtB2B - freteEfetivo);
                  mk(dono.id, 'vendedor', dono.percentual_comissao, lucroReal);
                }
                
                return { registros };
                """
              timeout = 10
            } as $calcComissao
          
            foreach ($calcComissao.registros) {
              each as $r {
                db.query Comissao {
                  where = $db.Comissao.orca_id == $OrcaC.id && $db.Comissao.user_id == $r.user_id && $db.Comissao.tipo == $r.tipo
                  return = {type: "list"}
                } as $jaExiste
              
                conditional {
                  if (($jaExiste|count) == 0) {
                    db.add Comissao {
                      enforce_hidden_fields = false
                      data = {
                        created_at     : "now"
                        user_id        : $r.user_id
                        orca_id        : $OrcaC.id
                        percentual     : $r.percentual
                        lucro_real_base: $r.base
                        base_valor     : $r.base
                        tipo           : $r.tipo
                        valor          : $r.valor
                        status         : "calculada"
                      }
                    } as $comissao_nova
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  response = $Boleto_1
  tags = ["pagamento", "novo-sis", "comissao"]
  guid = "pagamento-baixa-novo-sis-0001"
}