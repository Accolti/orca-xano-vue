// Recálculo dinâmico do orçamento (markup efetivo, frete B2C, desconto).
// Grava frtB2C/desconto no cabeçalho se informados, chama Orcamento_Recalcular_Totais
// e devolve o header + itens atualizados para o frontend renderizar.
query orcamento_recalcular verb=POST {
  api_group = "Default"
  auth = "User"

  input {
    int orca_id? {
      table = "Orca"
    }
  
    // Markup EFETIVO desejado (%) — Opção B. Se omitido, mantém a margem dos itens
    decimal newMargem?
  
    decimal frtB2C?
    decimal desconto?
  
    // Serviço de mão de obra — soma apenas no Total Geral
    decimal maoDeObra?
  
    // Observações gerais do orçamento
    text observacao? filters=trim
  
    // Condições de pagamento salvas (Pix/Boleto etc.)
    text condicoesPagamento? filters=trim
  
    // Estado do seletor de condições (JSON) — metodos, desconto Pix %, provedor/parcelas
    text condicoesPagamentoParams? filters=trim
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
  
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
    } as $Orca_0
  
    precondition ($Orca_0 != null) {
      error_type = "notfound"
      error = "Orçamento não encontrado."
    }
  
    precondition ($Orca_0.user_id == $auth.id) {
      error_type = "accessdenied"
      error = "Acesso negado: apenas o dono pode alterar o orçamento."
    }
  
    // ---- Política de desconto (F3): filho não altera margem e limites herdam/override ----
    db.get User {
      field_name = "id"
      field_value = $auth.id
      output = [
        "id"
        "role"
        "vendedor_pai_id"
        "desconto_livre_perc"
        "desconto_max_perc"
      ]
    } as $caller
  
    function.run f_perfil_efetivo {
      input = {user_id: $auth.id}
    } as $rootLim
  
    var $ehFilhoRec {
      value = (($caller.role == "vendedor") || ($caller.role == "vendedor_master"))
    }
  
    // Ancestrais a notificar (pai imediato + raiz, quando diferente)
    var $ancIds {
      value = []
    }
  
    conditional {
      if (($caller.vendedor_pai_id != null) && ($caller.vendedor_pai_id > 0)) {
        var.update $ancIds {
          value = $ancIds|append:$caller.vendedor_pai_id
        }
      }
    }
  
    conditional {
      if (($rootLim.id != null) && ($rootLim.id > 0) && ($rootLim.id != $caller.vendedor_pai_id)) {
        var.update $ancIds {
          value = $ancIds|append:$rootLim.id
        }
      }
    }
  
    var $margemUsar {
      value = null
    }
  
    conditional {
      if ($ehFilhoRec != true) {
        var.update $margemUsar {
          value = $input.newMargem
        }
      }
    }
  
    // Limites de desconto: o PONTA/MASTER herdam o PADRÃO DA EMPRESA (raiz) quando
    // não têm valor próprio (> 0). Sem nada cadastrado → 0 (bloqueia; banner sinaliza).
    var $livre {
      value = 0
    }
  
    var $maxDesc {
      value = 0
    }
  
    conditional {
      if (($caller.desconto_livre_perc != null) && ($caller.desconto_livre_perc > 0)) {
        var.update $livre {
          value = $caller.desconto_livre_perc
        }
      }
    
      else {
        conditional {
          if (($rootLim.desconto_livre_perc != null) && ($rootLim.desconto_livre_perc > 0)) {
            var.update $livre {
              value = $rootLim.desconto_livre_perc
            }
          }
        }
      }
    }
  
    conditional {
      if (($caller.desconto_max_perc != null) && ($caller.desconto_max_perc > 0)) {
        var.update $maxDesc {
          value = $caller.desconto_max_perc
        }
      }
    
      else {
        conditional {
          if (($rootLim.desconto_max_perc != null) && ($rootLim.desconto_max_perc > 0)) {
            var.update $maxDesc {
              value = $rootLim.desconto_max_perc
            }
          }
        }
      }
    }
  
    var $aprovado {
      value = true
    }
  
    var $gross {
      value = 0
    }
  
    var $descVal {
      value = 0
    }
  
    var $perc {
      value = 0
    }
  
    var $acimaMax {
      value = false
    }
  
    var $statusDesc {
      value = "aprovado"
    }
  
    var $paramsRaw {
      value = $input.condicoesPagamentoParams
    }
  
    conditional {
      if ($ehFilhoRec) {
        var.update $gross {
          value = $Orca_0.venda_bruta_tot|first_notnull:0
        }
      
        conditional {
          if ($gross == 0) {
            var.update $gross {
              value = ($Orca_0.vnd_tot|first_notnull:0) + ($Orca_0.desconto|first_notnull:0)
            }
          }
        }
      
        conditional {
          if ($gross > 0) {
            var.update $descVal {
              value = $input.desconto|first_notnull:0
            }
          
            var.update $perc {
              value = ($descVal * 100) / $gross
            }
          
            // Desconto Pix informado nas condições entra na MESMA política de limite
            api.lambda {
              code = """
                const raw = String($var.paramsRaw || '').trim();
                if (!raw) return { perc: 0 };
                try {
                  const o = JSON.parse(raw);
                  const p = Number(o && o.descontoPixPercentual);
                  return { perc: isNaN(p) || p < 0 ? 0 : p };
                } catch (e) {
                  return { perc: 0 };
                }
                """
              timeout = 5
            } as $pixInfo
          
            conditional {
              if (($pixInfo.perc|first_notnull:0) > $perc) {
                var.update $perc {
                  value = $pixInfo.perc
                }
              
                var.update $descVal {
                  value = ($gross * $perc) / 100
                }
              }
            }
          
            conditional {
              if ($perc > $maxDesc) {
                var.update $acimaMax {
                  value = true
                }
              }
            }
          
            conditional {
              if (($perc > $livre) && ($descVal > 0)) {
                var.update $aprovado {
                  value = false
                }
              }
            }
          }
        }
      }
    }
  
    // Estado do desconto (calculado APÓS a política) + notificação aos ancestrais
    conditional {
      if ($aprovado == false) {
        var.update $statusDesc {
          value = "pendente"
        }
      }
    }
  
    conditional {
      if (($ehFilhoRec) && ($aprovado == false) && ($Orca_0.desconto_status != "pendente")) {
        foreach ($ancIds) {
          each as $aid {
            db.add Notificacao {
              enforce_hidden_fields = false
              data = {
                created_at: "now"
                user_id   : $aid
                tipo      : "desconto_pendente"
                orca_id   : $input.orca_id
                lida      : false
              }
            } as $notif_nova
          }
        }
      }
    }
  
    precondition ($acimaMax != true) {
      error_type = "badrequest"
      error = "Desconto acima do máximo permitido para a equipe."
    }
  
    var $pedidoBloqueado {
      value = false
    }
  
    conditional {
      if ($Orca_0 != null) {
        var.update $pedidoBloqueado {
          value = ($Orca_0.eh_pedido == true)
        }
      }
    }
  
    precondition ($pedidoBloqueado != true) {
      error_type = "badrequest"
      error = "Orçamento convertido em pedido. Edição bloqueada."
    }
  
    // Grava frtB2C / desconto / mao_de_obra / observacao sempre (o frontend envia
    // todos, inclusive 0). Não usar first_notempty/first_notnull nem checagem
    // != null: o Xano trata 0 como vazio nesses casos e não gravaria.
  
    db.edit Orca {
      field_name = "id"
      field_value = $input.orca_id
      enforce_hidden_fields = false
      data = {
        frtB2C                    : $input.frtB2C
        desconto                  : $input.desconto
        desconto_aprovado         : $aprovado
        desconto_status           : $statusDesc
        mao_de_obra               : $input.maoDeObra
        observacao                : $input.observacao
        condicoes_pagamento       : $input.condicoesPagamento
        condicoes_pagamento_params: $input.condicoesPagamentoParams
      }
    } as $Orca_editada
  
    // Recálculo dinâmico por somatório
  
    function.run Orcamento_Recalcular_Totais {
      input = {
        orca_id           : $input.orca_id
        newMargem         : $margemUsar
        frt_b2b           : $rootLim.frtB2B|first_notnull:0
        frt_b2b_informado : true
      }
    } as $func_1
  
    // Header atualizado
  
    db.get Orca {
      field_name = "id"
      field_value = $input.orca_id
      addon = [
        {
          name : "Cliente"
          input: {Cliente_id: $output.cliente_id}
          as   : "_cliente"
        }
      ]
    } as $Orca_1
  }

  response = {
    ORCA_1: $Orca_1
    itemS : $func_1.itemS
    totais: $func_1.totais
  }

  guid = "qOJ_kl6s9uhZdqajy8GcKg"
}