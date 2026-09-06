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

Status: **parcialmente feito** (seletor de instituição ⭐, checkboxes Pix/Boleto/Cartão, desconto Pix com impacto em lucro/margem, mesclagem de métodos + "trazer todas as parcelas", repasse da taxa cartão — `src/utils/condicoesPagamento.ts`/`taxasBanco.ts`). Falta: tela admin central de métodos + parametrização no perfil.

- [ ] Tela admin: lista central de métodos (Pix/Dinheiro, Boleto, Cartão, Faturamento Direto) com toggles ON/OFF
- [ ] Regras por método: **desconto incentivo Pix** (✅ já no front, falta parametrizar), parcela mínima boleto, máx. parcelas sem juros cartão + **repasse taxa** (✅ já no front), prazos fixos por perfil + valor mínimo faturamento direto
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

Status: **fase inicial feita (2026-09)** — roles + gestão de equipe (`/equipe`). Comissões, permissões visuais e planos pendentes (planos de Comissões Fase A abaixo).

### Feito ✅ (fase inicial)
- `User.role` (`admin_geral`/`admin`/`vendedor`) + `vendedor_pai_id` + `percentual_comissao` + `ativo` (legado sem role = admin)
- Endpoints: `GET /equipe`, `POST /equipe_criar`, `POST /equipe_vincular`, `POST /equipe_editar` (auth User; dono/`admin_geral`)
- `EquipeView.vue` (rota `/equipe`, menu 👥 só p/ admin) — criar vendedor (login/senha inicial), vincular conta existente, editar %/desativar
- `auth.ts`: helpers `isAdminGeral`/`isAdmin`/`isVendedor`

### Pendente
- [ ] **Permissões visuais (F3)**: vendedor NÃO vê custo da empresa (ocultar cst/markup/margem real); só quem tem "chave" vê
- [ ] Limite de desconto por vendedor
- [ ] Planos/assinaturas (vendedor compra plano; sub-vendedores com comissão)
- [ ] **Tela de comissões pagas aos vendedores-filhos**: lista por vendedor, período, valor da comissão, status (calculada/paga) — depende de `vendedor_pai_id` + `percentual_comissao`. Rota própria `/comissoes`

### Comissões — Fase A (plano aprovado em 2026-09 — implementar depois)

Modelo decidido: **empresa com vendedores** (role `admin` = dono/gestor, `vendedor` = subordinado), comissão do vendedor sobre o **lucro real do pedido**, gatilho **ao receber** (implementar como "pedido 100% pago" — todas as parcelas recebidas).

- **Dados**: `User.role` (`admin` default das contas atuais | `vendedor`), `User.vendedor_pai_id` (FK User), `User.percentual_comissao`. Tabela `Comissao` (append-only): `user_id`, `orca_id`, `percentual`, `lucro_real_base`, `valor`, `status` (`calculada`|`paga`), `data_pagamento`; lançamento único por `orca_id`.
- **Backend**:
  - `pagamento_baixa`: ao deixar o pedido 100% pago, calcula `lucro_real` (mesma fórmula do `/relatorio`: `luc_tot + desconto_kapazi + (frtB2B − frete_efetivo)`, % do `Desconto_Kapazi_Log`/`ControlePedido`) e insere `Comissao` do dono (`Orca.user_id`) quando tem `vendedor_pai_id`; idempotente; estorno não remove.
  - `GET /equipe` (admin) · `POST /equipe_vincular {email, percentual}` · `POST /equipe_criar {name, email, password, percentual}` · `GET /comissoes` (período; admin vê vendedores filhos, vendedor vê os dele) · `POST /comissao_pagar {comissao_id}`.
- **Front**: `auth` User + helpers `isAdmin`/`isVendedor`; rotas `/equipe` e `/comissoes`; views `EquipeView` (vincular/criar/editar %) e `ComissoesView` (chips de período, tabelas, "Marcar paga"); menu condicional por role.
- **Fases futuras**: B — permissões visuais (vendedor sem custo/markup/margem, limite de desconto); C — planos/assinaturas e (se preciso) `vendedor_master` (2 níveis).

## 📊 Frente 4 — Relatórios e controle financeiro

Status: registrada (implementação futura) — origem: `LEGADO.md`/contexto do projeto

- [x] **Relatório de funil/apontamentos** usando o `Orca_Status_Log` (histórico de transições RASCUNHO → … → ENTREGUE, tempos por etapa, taxas de conversão) — seção **Funil** de `/relatorios` (2026-09)
- [x] **Relatório financeiro com lucro/margem real** (Opção A decidida — não assar no banco, calcular no relatório) — seção **Financeiro** de `/relatorios` (2026-09). A fonte do histórico é o `Desconto_Kapazi_Log` (abaixo). Cálculo:
  - `custo_kapazi_total` = Σ (`item.vlr_cst_nota_unit` × `qtd`) — custo da mercadoria, **sem frete**
  - `desconto_kapazi` = `custo_kapazi_total` × `desconto_kapazi_perc` / 100
  - **Frete efetivo**: usar `ControlePedido.freteB2BReal` quando preenchido; senão `Orca.frtB2B` (o frete **fechado no orçamento** — nunca recalcular do zero nem buscar na tabela User atual)
  - `lucro_real = luc_tot + desconto_kapazi + (Orca.frtB2B − frete_efetivo_real)`
  - `margem_real = lucro_real / vnd_tot × 100`
  - Base de desconto usa `vlr_cst_nota_unit` (mercadoria pura); o frete é somado à parte (proporcional na criação, efetivo no fechamento)
- [x] **Frete B2B (regra do mínimo)**: removido o parâmetro morto `seu_frete_minimo: 52` do `Orcamento_Recalcular_Totais` — o mínimo agora vem só de **`User.frtB2B`** (`f_calcula_frete` lê `$User1.frtB2B`). O relatório `/relatorios` expõe o **`frete_efetivo`** (`freteB2BReal` senão `Orca.frtB2B`) e o `lucro_real` usa a diferença `frtB2B − frete_efetivo`.
- [x] **Log de descontos Kapazi**: tabela append-only `Desconto_Kapazi_Log` criada (padrão `Orca_Status_Log`) — registra **toda mudança** de `ControlePedido.desconto_kapazi_perc`; consumida **só pelos relatórios** (o resumo da finalizada continua mostrando o valor atual). Gravada pelo `controle_pedido_salvar` quando o % muda; o campo `desconto_kapazi_perc` segue sendo o "valor vivo". Schema criado:

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
- [x] **Boletos**: telas de controle e fluxo de baixa construídas em `/pagamentos` (ver **Frente 6**) — `Boleto.orca_id`, abas de status + filtro de período, `PagamentoModal` no orçamento
- [ ] **Controle de Pedidos**: painel consolidado do fluxo Kapazi (enviado → nº fábrica → aprovação layout → NF → boletos → entregue) com status e prazos
- [ ] **SAC (pós-venda)**: tabela própria de atendimento/reclamações por pedido (não engessar no fluxo atual)

## 🧹 Frente 5 — Perfil do usuário (2ª fase) e limpeza do legado

Status: registrada (implementação futura)

- [ ] **Perfil 2ª fase**: telefone/endereço do usuário, logo, troca de e-mail com verificação (a 1ª fase já existe — `PerfilModal.vue`)
- [ ] **Automação Kapazi** (futura): integração para receber/registrar status e dados da fábrica automaticamente
- [ ] **Limpeza do legado**: rodar `MigrarPedidosParaOrca`, depois excluir as funções/endpoints `PARA EXCLUIR` do `LEGADO.md`, dropar tabelas `Pedido`/`item_ped`/`controle_pedido` e a coluna `orca.pedido_id`

## 💵 Frente 6 — Controle de Pagamentos

Status: **feito (fase 1, 2026-09)** — vínculo em `Orca` (`Boleto.orca_id`), telas, filtros e baixa manual. Detalhes na seção "Controle Financeiro" do [`docs/FUNCIONALIDADES.md`](docs/FUNCIONALIDADES.md).

- [x] Página `/pagamentos` (menu "Boletos" ativo): lista de parcelas por orçamento com `cod_orca` + selo "(Pedido)"
- [x] Abas de status: Todos / **Em aberto** (= todas as não pagas) / A vencer / Vencidos / Pagos
- [x] **Filtro de período**: "Período a partir de" (mês, default atual) + Mensal/Trimestral/Semestral/Anual (janela de vencimento do 1º do mês + 1/3/6/12 meses; vencidas sempre entram; combina com a aba de status)
- [x] `PagamentoModal` no orçamento (💳 Financeiro) com "Gerar das condições" + edição de valor/vencimento/forma
- [x] Baixa manual (`pagamento_baixa`: marca/estorna `pagamento`) + `pagamento_salvar` (substitui parcelas) + `pagamento_excluir`
- [x] **Faturar** = salvar parcelas + avançar status (`AGUARDANDO_FATURAMENTO → FATURADO`); status pós-conversão: FATURADO/ENTREGUE/CANCELADO (RECUSADO bloqueado)
- [x] Backend `pagamentos`/`pagamento_salvar`/`pagamento_baixa`/`pagamento_excluir` (auth User) + `Boleto.orca_id`
- [ ] Gateway de pagamento (boleto registrado/Pix) — hoje é controle interno + baixa manual
- [ ] Tabela `Boleto` legada (`pedido_id`) — limpeza na migração (Frente 5)

## 📈 Frente 7 — Relatórios gerenciais

Status: **feito (2026-09)** — página `/relatorios` com Financeiro de Pedidos, Recebidos por período e Funil (menu "Relatórios" habilitado). Endpoint `GET /relatorio` (auth User, `mes_inicio` + `periodo`), mesmo padrão de janela do dashboard. Detalhes no [`docs/FUNCIONALIDADES.md`](docs/FUNCIONALIDADES.md).

- [x] Página `/relatorios` (ativa o menu "Relatórios")
- [x] **Relatório financeiro**: custo Kapazi, desconto Kapazi, frete efetivo, lucro/margem real (fórmulas da Frente 4; `Desconto_Kapazi_Log` criado e alimentado pelo `controle_pedido_salvar`)
- [x] **Recebidos por período** (sobre `Boleto`/`Orca`, substitui o `f_relatorio_recebidos` legado que join-ava `Pedido`)
- [x] **Funil de status** (`Orca_Status_Log`: transições na janela, conversão → APROVADO, tempo médio até APROVAÇÃO)

## 📊 Frente 8 — Dashboard (HomeView)

Status: **feito (2026-09)** — dashboard + funil + filtro de período + gráficos mensais implementados.

- [x] HomeView vira dashboard: cards Orçamentos/Pedidos/Boletos vencidos / a vencer / pagos (clicáveis) + chips do funil de status que navegam para `/orcamentos?status=`
- [x] **Filtro de período no dashboard**: `dashboard_GET` com `mes_inicio`/`periodo` (contagem em `api.lambda`, sem `fDadosDashBoard`); orçamentos/pedidos/funil por `created_at`, boletos na mesma fonte/regra do `/pagamentos` (vencidos sempre, a vencer/pagos na janela)
- [x] **Gráficos no dashboard**: `dashboard_GET` devolve `serie[]` mensal (`mes`, `vendas`, `recebido`, `areceber`) no domínio do filtro (`todos` = todo histórico); `DashboardGrafico.vue` renderiza **Vendas por mês (R$)** (até o mês atual) e **Recebido vs A receber (R$)** (janela completa, com projeção futura de a receber) em barras CSS, espelhando a barra de período

## 🧮 Frente 9 — Normalização de custo e fator de corte

Status: **parcialmente feito** (2026-08) — herança de custo e `modo_corte` no fator implementados.

### Feito ✅
- **Herança de custo (A1)**: `produto_cadastrar` — variação sem `valor_custo` herda `Produto.valor`; UND/KIT/ML exigem custo base `> 0`. Só na dev tool; produção intacta.
- **Fator de corte `modo_corte`** (`lista` | `passo`): `Fator_de_Corte.modo_corte`; `passo` reutiliza `comp_corte` (arredonda sempre ao múltiplo — ex.: 0,5m). `f_retorna_fc` e `f_valor_custo_m2` atualizados.
- **Opção X — fator fixo no produto**: `Produto.fator_de_corte_id` (prioridade 1 no M2); fallback `Tipo_Fator` (material+linha+borda); sem fator → dimensões originais.
- **Dev tools**: `/dev/produtos` com campo "Fator de Corte"; `/dev/fatores` (CRUD de `Fator_de_Corte` + associações `Tipo_Fator`, com bloqueio de exclusão em uso).
- **Produto composto genérico**: `Base_de_Calculo=COMPOSTO` + `Produto.tipo_composto` (ex.: "playkap"). PLAYKAP = piso modular (placas 30cm + rampas macho/fêmea + cantoneiras, compra mínima), com **controle de rampa por lado** (`rampa_larg1/comp1/larg2/comp2`) e composição gravada em `item.detalhes_calculo` (JSON) sem poluir a `Descricao`. Avulsos (Placa/Rampa/Cantoneira) como produtos UND separados. Ver `docs/FUNCIONALIDADES.md`.

### Pendente (futuro)
- [ ] **A2 — tabela `Preco_Produto` centralizada** (histórico/validade de preço) — só vale quando houver necessidade real; hoje a herança no cadastro resolve.
- [ ] Borda: manter como está (complemento por material via `Borda.valor`) — decidido não mover para o produto (duplicaria informação).

## 🧾 Frente 10 — Formas de receber & taxas por conta (piloto → base Asaas)

Status: **levantamento aprovado (2026-09)** — implementação futura. Origem: revisão de "novos usuários" + roadmap Asaas (planos Básico/afiliados, boleto/NF via Asaas).

### Decisões do piloto
- **Herdar o existente por padrão**: enquanto uma conta não cadastra as próprias taxas/condições, usa a **tabela global atual** (`Taxa_Banco`) — sem quebra p/ contas atuais.
- **Cada conta (vendedor) pode cadastrar a SUA forma de operar as condições de pagamento** — exige **front + adequações** (hoje é global e sem tela).
- **Cadastro manual a priori**; ideia futura: "inteligência" buscar taxas padrão de adquirentes e popular automaticamente.
- **Distinção de canal de cobrança** (hoje inexistente): **link de pagamento**, **maquininha/POS**, **celular**, Pix e boleto têm **taxas diferentes** — o cartão muda conforme o canal (online/link vs presencial/POS).

### Modelo de dados (proposta)
- `Taxa_Banco` ganha **`user_id`** (nulo = tabela global/default) e **`canal`** (`cartao_link` | `cartao_pos` | `cartao_celular` | `pix` | `boleto`), mantendo `provedor_id`/`provedor`, `parcelas`, `cc_taxa`, `ativo`.
- Nova **`Preferencia_Pagamento_User`** (por user/conta): métodos ativos (Pix/Boleto/Cartão/Link), desconto Pix padrão, máx. parcelas sem juros **por canal**, repasse de taxa, prazos fixos.
- Forma de receber é **informativa** no piloto (chave Pix/dados da conta p/ referência) — sem emissão.

### Front & adequações (piloto)
- Tela **"Como recebo & condições"** (admin da conta): cadastro canal × provedor × parcelas × taxa + métodos/prazos/repasse/desconto Pix.
- **Seletor de condições do orçamento**: usa as taxas da **conta do dono do orçamento** (fallback global); permite escolher o **canal de cobrança** aplicando a taxa do canal na condição; refletir no texto quando fizer sentido.
- Cache de `taxas_banco` **por user** (chave inclui `user_id`).

### Backend (piloto)
- `taxas_banco` GET filtra por `user_id` com fallback global; CRUD por user validando owner; `Preferencia_Pagamento_User` GET/POST (owner).

### Fases futuras (pós-piloto)
- **Auto-taxas**: cadastro inteligente de tabelas padrão por adquirente/canal.
- **Asaas**: vínculo de conta (API key/customer), emissão Pix/Boleto/Cartão-link (`billingType`) e NF; webhook marca baixa; tabela da conta segue alimentando o cálculo das condições.
- **Planos**: Básico (1 admin = vendedor único) e Vendedores + Afiliados → hierarquia (F3) + split Asaas.
- Maquininha/POS/celular: controle **manual** no Financeiro (fora do link).

