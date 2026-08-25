# Roadmap / Ideias — Orca Xano Vue

Status geral: ideias registradas; implementação por fases (decidir prioridade depois).

## 🗂 Frente 1 — Documentos em pastas compartilhadas (Google Drive)

Status: **decisão tomada** — hoje = escolha de destino local; upload/link = futuro (depende de plano Xano pago)

> **Decisão (2026-08)**: configurar pasta compartilhada **por usuário** é inviável (credencial de cada vendedor). Upload para o Xano (storage) + enviar **link** ao cliente em vez do arquivo só faz sentido quando o Xano for pago. Por enquanto, o PDF é gerado no front e o usuário **escolhe o destino**:
> - **Desktop (Chrome/Edge)**: diálogo nativo "Salvar como" (`showSaveFilePicker`) — o usuário navega até a pasta que quiser (ex.: `G:\orcamentos\`).
> - **Mobile**: Web Share API com o arquivo (`navigator.share({ files })`) — o SO oferece salvar em Arquivos/Drive/enviar.
> - **Fallback** (Firefox/Safari desktop): download padrão do navegador (como antes).
> Implementado em `src/services/pdf.ts` (helper `salvarPdf` usado por `gerarPdfOrcamento` e `gerarPdfPedidoVenda`). **Sem tabela.**

### Futuro (plano Xano pago / Google Drive API)

- [ ] Migrar para API (service account / OAuth) — pasta global por CNPJ
- [ ] Upload automático do PDF na pasta correta ao gerar/converter em pedido
- [ ] Enviar **link** ao cliente em vez do arquivo
- [ ] Página para cadastrar os links/credenciais + manual para os vendedores
- [ ] Botão "Abrir pasta" no app (Orçamentos e Pedidos)

### PDF de Pedido de Venda

- [ ] Novo template `gerarPdfPedidoVenda` (distinto do "Orçamento de Venda" atual)
- [ ] Incluir todas as opções negociadas (condições de pagamento, frete, desconto, validade) + valor final
- [ ] **Pedido de Venda aparece na Lista de Pedidos** (além do orçamento)

## 💳 Frente 2 — Parametrização de Condições de Pagamento

Status: registrada (implementação futura)

- [ ] Tela admin: lista central de métodos (Pix/Dinheiro, Boleto, Cartão, Faturamento Direto) com toggles ON/OFF
- [ ] Regras por método: desconto incentivo Pix, parcela mínima boleto, máx. parcelas sem juros cartão + repasse taxa, prazos fixos por perfil + valor mínimo faturamento direto
- [ ] Trava do Custo de Fábrica: Max Parcelas = floor(V_venda ÷ P_fabrica), P_fabrica = C_fabrica ÷ N_fabrica
- [ ] Trava no front (dropdown de parcelas limitado + aviso)
- [ ] Simulador em tempo real no painel de config ("Liberado em até 4x no boleto")

### Simulação parametrizável (margens) + olho de custo/lucro

> Status: **parcialmente feito** — faixa fixa 50–100 passo 10 com rótulos `c5..c10`, olho 👁 e clique→pagamento implementados (`src/utils/simulacao.ts`). Falta: parametrização no perfil (campos `margem_sim_inicio/fim/passo`).

- [x] Função JS no front `gerarSimulacaoFront(custo, qtd)` (faixa fixa 50–100 passo 10, rótulos `c5..c10`)
- [x] **Olho (👁) na simulação**: botão `btn-eye` para mostrar/ocultar custo e lucro (oculto por padrão)
- [x] **Clique na linha → condições de pagamento** (mantido da modal existente)
- [x] Botão "Simulação" no Ajustar Orçamento (quadro de totais) abre a modal
- [ ] Campos no `User` (perfil): `margem_sim_inicio`, `margem_sim_fim`, `margem_sim_passo`
- [ ] Guardrails configuráveis (atualmente: passo mínimo 5, amplitude máxima 200)

## 👥 Frente 3 — Multi-vendedor, planos, comissão e permissões

Status: registrada (implementação futura)

- [ ] `role` no User (admin / vendedor_master / vendedor) + `vendedor_pai_id` + `percentual_comissao`
- [ ] Visibilidade por permissão: vendedor NÃO vê custo da empresa (ocultar cst/markup/margem real); só quem tem "chave" vê
- [ ] Limite de desconto por vendedor
- [ ] Planos/assinaturas (vendedor compra plano; sub-vendedores com comissão)
- [ ] **Tela de comissões pagas aos vendedores-filhos**: lista por vendedor, período, valor da comissão, status (calculada/paga) — depende de `vendedor_pai_id` + `percentual_comissao`. Rota própria `/comissoes`

## 📊 Frente 4 — Relatórios e controle financeiro

Status: registrada (implementação futura) — origem: `LEGADO.md`/contexto do projeto

- [ ] **Relatório de funil/apontamentos** usando o `Orca_Status_Log` (histórico de transições RASCUNHO → … → ENTREGUE, tempos por etapa, taxas de conversão)
- [ ] **Relatório financeiro com lucro/margem real** (Opção A decidida — não assar no banco, calcular no relatório). A fonte do histórico é o `Desconto_Kapazi_Log` (abaixo). Cálculo:
  - `custo_kapazi_total` = Σ (`item.vlr_cst_nota_unit` × `qtd`) — custo da mercadoria, **sem frete**
  - `desconto_kapazi` = `custo_kapazi_total` × `desconto_kapazi_perc` / 100
  - **Frete efetivo**: usar `ControlePedido.freteB2BReal` quando preenchido; senão `Orca.frtB2B` (o frete **fechado no orçamento** — nunca recalcular do zero nem buscar na tabela User atual)
  - `lucro_real = luc_tot + desconto_kapazi + (Orca.frtB2B − frete_efetivo_real)`
  - `margem_real = lucro_real / vnd_tot × 100`
  - Base de desconto usa `vlr_cst_nota_unit` (mercadoria pura); o frete é somado à parte (proporcional na criação, efetivo no fechamento)
- [x] **Frete B2B (regra do mínimo)**: removido o parâmetro morto `seu_frete_minimo: 52` do `Orcamento_Recalcular_Totais` — o mínimo agora vem só de **`User.frtB2B`** (`f_calcula_frete` lê `$User1.frtB2B`). **Falta**: comparativo calculado × efetivo (`freteB2BReal`) no relatório, que usa `Orca.frtB2B` (valor fechado).
- [ ] **Log de descontos Kapazi**: tabela append-only `Desconto_Kapazi_Log` (padrão `Orca_Status_Log`) — registra **toda mudança** de `ControlePedido.desconto_kapazi_perc`, consumida **só pelos relatórios** (o resumo da finalizada continua mostrando o valor atual). Gravada pelo `controle_pedido_salvar` quando o % muda; o campo `desconto_kapazi_perc` segue sendo o "valor vivo". Schema sugerido:

  ```xano
  table Desconto_Kapazi_Log {
    auth = false

    schema {
      int id
      timestamp created_at?=now { visibility = "private" }

      int orca_id? { table = "Orca" }

      // Desconto anterior e novo (em %)
      decimal desconto_anterior?
      decimal desconto_novo?

      // Valor do desconto em R$ na data do log (base = Σ vlr_cst_nota_unit × qtd)
      decimal valor_desconto_rs?

      // Frete efetivo em uso no momento do log (Orca.frtB2B ou ControlePedido.freteB2BReal)
      decimal frete_efetivo_rs?

      // Quem gravou
      int user_id? { table = "User" }

      // Motivo/observação opcional (ex.: negociação com a fábrica)
      text motivo? filters=trim
    }

    index = [
      {type: "primary", field: [{name: "id"}]}
      {
        type : "btree"
        field: [{name: "orca_id", op: "asc"}, {name: "created_at", op: "desc"}]
      }
      {type: "gin", field: [{name: "xdo", op: "jsonb_path_op"}]}
    ]
  }
  ```
- [ ] **Boletos**: base já existe no backend (`Boleto`, `f_boleto_pago`, `f_boleto_a_vencer`, `f_boleto_vencido`, `f_sum_pedidos_boletos`) — construir telas de controle (em aberto / a vencer / vencidos / recebidos) e fluxo de baixa
- [ ] **Controle de Pedidos**: painel consolidado do fluxo Kapazi (enviado → nº fábrica → aprovação layout → NF → boletos → entregue) com status e prazos
- [ ] **SAC (pós-venda)**: tabela própria de atendimento/reclamações por pedido (não engessar no fluxo atual)

## 🧹 Frente 5 — Perfil do usuário (2ª fase) e limpeza do legado

Status: registrada (implementação futura)

- [ ] **Perfil 2ª fase**: telefone/endereço do usuário, logo, troca de e-mail com verificação (a 1ª fase já existe — `PerfilModal.vue`)
- [ ] **Automação Kapazi** (futura): integração para receber/registrar status e dados da fábrica automaticamente
- [ ] **Limpeza do legado**: rodar `MigrarPedidosParaOrca`, depois excluir as funções/endpoints `PARA EXCLUIR` do `LEGADO.md`, dropar tabelas `Pedido`/`item_ped`/`controle_pedido` e a coluna `orca.pedido_id`

## 💵 Frente 6 — Controle de Pagamentos

Status: registrada (implementação futura)

- [ ] Página `/pagamentos` (ativa o menu "Boletos"): lista de parcelas por pedido (boleto: valor + nº de parcelas + vencimentos; pix; etc.)
- [ ] Abas/filtros: Em aberto / A vencer / Vencidos / Pago (reusa `fBoleto_*` com `Tipo: "Dados"`)
- [ ] Baixa manual de pagamento (registrar `pagamento`) + ajuste de valor/vencimento
- [ ] **Migrar `Boleto` para `Orca`**: tabela ganha `orca_id` (substitui `pedido_id` legado); `fBoleto_Vencido`/`A_Vencer`/`Pago`, `f_relatorio_recebidos` e `fSumPedidosBoletos` passam a usar Orca (vínculo resolvido por `Orca.pedido_id` legado → `cod_orca` ou direto)

## 📈 Frente 7 — Relatórios gerenciais

Status: registrada (implementação futura)

- [ ] Página `/relatorios` (ativa o menu "Relatórios")
- [ ] **Relatório financeiro**: custo Kapazi, desconto Kapazi, frete efetivo, lucro/margem real (fórmulas já mapeadas na Frente 4; fonte = `Desconto_Kapazi_Log`)
- [ ] **Recebidos por período** (reusa `f_relatorio_recebidos` adequado para Orca)
- [ ] **Funil de status** (`Orca_Status_Log`)

## 📊 Frente 8 — Dashboard (HomeView)

Status: registrada (implementação futura)

- [ ] HomeView vira dashboard: cards com Orçamentos, Pedidos, Boletos vencidos / a vencer / pagos (já calculados em `fDadosDashBoard`)
- [ ] **Status em destaque** (funil: RASCUNHO / AGUARDANDO_RETORNO / APROVADO / PEDIDO / ...)
- [ ] Gráficos simples (vendas por mês, recebido vs a receber)

## 🧮 Frente 9 — Normalização de custo e fator de corte

Status: **parcialmente feito** (2026-08) — herança de custo e `modo_corte` no fator implementados.

### Feito ✅
- **Herança de custo (A1)**: `produto_cadastrar` — variação sem `valor_custo` herda `Produto.valor`; UND/KIT/ML exigem custo base `> 0`. Só na dev tool; produção intacta.
- **Fator de corte `modo_corte`** (`lista` | `passo`): `Fator_de_Corte.modo_corte`; `passo` reutiliza `comp_corte` (arredonda sempre ao múltiplo — ex.: 0,5m). `f_retorna_fc` e `f_valor_custo_m2` atualizados.
- **Opção X — fator fixo no produto**: `Produto.fator_de_corte_id` (prioridade 1 no M2); fallback `Tipo_Fator` (material+linha+borda); sem fator → dimensões originais.
- **Dev tools**: `/dev/produtos` com campo "Fator de Corte"; `/dev/fatores` (CRUD de `Fator_de_Corte` + associações `Tipo_Fator`, com bloqueio de exclusão em uso).

### Pendente (futuro)
- [ ] **A2 — tabela `Preco_Produto` centralizada** (histórico/validade de preço) — só vale quando houver necessidade real; hoje a herança no cadastro resolve.
- [ ] Borda: manter como está (complemento por material via `Borda.valor`) — decidido não mover para o produto (duplicaria informação).
