// Limpeza one-off de registros órfãos (filhos cujo "pai" foi apagado) e de
// referências penduradas (FK apontando para registro inexistente).
//
// Exclui:
//   - Endereco_Cliente  com cliente_id inexistente
//   - Telefone_Cliente  com cliente_id inexistente
//   - item              com orca_id inexistente
//   - Gerados           com orca_id inexistente
//   - Orca_Status_Log   com orca_id inexistente
//
// Anula (seta 0 = "sem referência") FKs penduradas:
//   - Cliente.regime_id  inexistente
//   - item.produto_id    inexistente
//   - item.variacao_id   inexistente
//
// Idempotente: rodar de novo não encontra mais órfãos.
// Executar UMA VEZ no dashboard (Run & Debug / função).
function deletar_orfaos {
  input {
  }

  stack {
    // ===== pais (ids) =====
    db.query Cliente {
      return = {type: "list"}
      output = ["id"]
    } as $clientes

    db.query Orca {
      return = {type: "list"}
      output = ["id"]
    } as $orcas

    db.query Regime {
      return = {type: "list"}
      output = ["id"]
    } as $regimes

    db.query Produto {
      return = {type: "list"}
      output = ["id"]
    } as $produtos

    db.query Variacao {
      return = {type: "list"}
      output = ["id"]
    } as $variacoes

    // ===== filhos (com as FKs) =====
    db.query Endereco_Cliente {
      return = {type: "list"}
      output = ["id", "cliente_id"]
    } as $enderecos

    db.query Telefone_Cliente {
      return = {type: "list"}
      output = ["id", "cliente_id"]
    } as $telefones

    db.query item {
      return = {type: "list"}
      output = ["id", "orca_id", "produto_id", "variacao_id"]
    } as $itens

    db.query Gerados {
      return = {type: "list"}
      output = ["id", "orca_id"]
    } as $gerados

    db.query Orca_Status_Log {
      return = {type: "list"}
      output = ["id", "orca_id"]
    } as $logs

    // ===== calcula órfãos e referências penduradas =====
    api.lambda {
      code = """
        const ids = (arr) => new Set((arr || []).map((x) => Number(x.id)));
        const clientes = ids($var.clientes);
        const orcas = ids($var.orcas);
        const regimes = ids($var.regimes);
        const produtos = ids($var.produtos);
        const variacoes = ids($var.variacoes);
        const fkOk = (v, set) => { const n = Number(v) || 0; return n === 0 || set.has(n); };

        const enderecos = ($var.enderecos || []).filter((e) => !fkOk(e.cliente_id, clientes)).map((e) => e.id);
        const telefones = ($var.telefones || []).filter((t) => !fkOk(t.cliente_id, clientes)).map((t) => t.id);
        const itens = ($var.itens || []).filter((i) => !fkOk(i.orca_id, orcas)).map((i) => i.id);
        const gerados = ($var.gerados || []).filter((g) => !fkOk(g.orca_id, orcas)).map((g) => g.id);
        const logs = ($var.logs || []).filter((l) => !fkOk(l.orca_id, orcas)).map((l) => l.id);

        const itensDeletados = new Set(itens.map(Number));

        const clientesRegime = ($var.clientes || []).filter((c) => !fkOk(c.regime_id, regimes)).map((c) => c.id);
        const itensProduto = ($var.itens || []).filter((i) => !itensDeletados.has(Number(i.id)) && !fkOk(i.produto_id, produtos)).map((i) => i.id);
        const itensVariacao = ($var.itens || []).filter((i) => !itensDeletados.has(Number(i.id)) && !fkOk(i.variacao_id, variacoes)).map((i) => i.id);

        return {
          enderecos: enderecos,
          telefones: telefones,
          itens: itens,
          gerados: gerados,
          logs: logs,
          clientesRegime: clientesRegime,
          itensProduto: itensProduto,
          itensVariacao: itensVariacao,
        };
        """
      timeout = 10
    } as $orfaos

    db.transaction {
      stack {
        foreach ($orfaos.enderecos) {
          each as $id {
            db.del Endereco_Cliente {
              field_name = "id"
              field_value = $id
            }
          }
        }

        foreach ($orfaos.telefones) {
          each as $id {
            db.del Telefone_Cliente {
              field_name = "id"
              field_value = $id
            }
          }
        }

        foreach ($orfaos.itens) {
          each as $id {
            db.del item {
              field_name = "id"
              field_value = $id
            }
          }
        }

        foreach ($orfaos.gerados) {
          each as $id {
            db.del Gerados {
              field_name = "id"
              field_value = $id
            }
          }
        }

        foreach ($orfaos.logs) {
          each as $id {
            db.del Orca_Status_Log {
              field_name = "id"
              field_value = $id
            }
          }
        }

        foreach ($orfaos.clientesRegime) {
          each as $id {
            db.edit Cliente {
              field_name = "id"
              field_value = $id
              enforce_hidden_fields = false
              data = {regime_id: 0}
            }
          }
        }

        foreach ($orfaos.itensProduto) {
          each as $id {
            db.edit item {
              field_name = "id"
              field_value = $id
              enforce_hidden_fields = false
              data = {produto_id: 0}
            }
          }
        }

        foreach ($orfaos.itensVariacao) {
          each as $id {
            db.edit item {
              field_name = "id"
              field_value = $id
              enforce_hidden_fields = false
              data = {variacao_id: 0}
            }
          }
        }
      }
    }
  }

  response = {
    enderecos_excluidos     : $orfaos.enderecos|count
    telefones_excluidos     : $orfaos.telefones|count
    itens_excluidos         : $orfaos.itens|count
    gerados_excluidos       : $orfaos.gerados|count
    logs_excluidos          : $orfaos.logs|count
    clientes_regime_anulado : $orfaos.clientesRegime|count
    itens_produto_anulado   : $orfaos.itensProduto|count
    itens_variacao_anulado  : $orfaos.itensVariacao|count
    total_excluidos         : ($orfaos.enderecos|count)|add:($orfaos.telefones|count)|add:($orfaos.itens|count)|add:($orfaos.gerados|count)|add:($orfaos.logs|count)
  }

  tags = ["migracao", "limpeza"]
  guid = "deletar-orfaos-0001"
}
